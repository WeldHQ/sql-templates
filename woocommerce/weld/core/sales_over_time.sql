-- core.woocommerce.sales_over_time
-- Recreates WooCommerce Analytics' Revenue report (gross sales, coupons, refunds,
-- net sales, taxes, shipping, total sales) at a grain you can slice.
--
-- Grain: day x store x order x row type. row_type is SALE for the order itself and
-- RETURN for its refunds, so a day on which an order both sells and refunds gives
-- two rows and each side stays auditable. Aggregate to day in BI.
--
-- Event-based: a refund is its own row in wc_order_stats, dated when the refund
-- was made, so returns land on the refund date and history does not restate when
-- an old order is refunded. order_id is always the ORIGINAL order, also on RETURN
-- rows.
--
-- Matches Analytics' own rules, read from the store's settings:
--   * Report date: the "Date type" analytics setting (date paid by default). Rows
--     with no value for that date, such as unpaid orders under "date paid", are
--     left out, as Analytics does.
--   * Statuses: the "Excluded statuses" analytics setting (pending, failed and
--     cancelled by default), plus auto-draft and trash, which Analytics always
--     excludes. A refund carries its parent order's status, so it is excluded
--     together with its order.
--
-- Discounts: Analytics reads coupons from wc_order_coupon_lookup, which the
-- connector does not sync. They are taken from the per-line coupon_amount in
-- wc_order_product_lookup instead, which is the same coupon value allocated to
-- product lines. Expect cent-level rounding differences against Analytics.
--
-- Currency: the store currency (store_settings.currency, the CURRENT setting).
-- Time: store-local, as WooCommerce writes it; no conversion needed.
--
-- Depends on: staging.woocommerce.order_stats, .order_product_lookup,
--             .store_settings

WITH settings AS (
    SELECT
        woocommerce_store,
        currency,
        COALESCE(analytics_date_type, 'date_paid') AS date_type,
        ARRAY_CONCAT(
            ['wc-auto-draft', 'wc-trash'],
            COALESCE(excluded_statuses, ['wc-pending', 'wc-failed', 'wc-cancelled'])
        ) AS excluded_statuses
    FROM {{staging.woocommerce.store_settings}}
),

-- Coupon value per order, from the order's product lines. Pre-aggregated to one
-- row per order so the join below cannot fan out.
order_coupons AS (
    SELECT woocommerce_store, order_id, SUM(coupon_amount) AS coupon_amount
    FROM {{staging.woocommerce.order_product_lookup}}
    GROUP BY woocommerce_store, order_id
),

stats AS (
    SELECT
        s.woocommerce_store,
        st.currency,
        -- RETURN rows report against the original order.
        CASE WHEN s.is_refund THEN s.parent_id ELSE s.order_id END AS order_id,
        CASE WHEN s.is_refund THEN 'RETURN' ELSE 'SALE' END        AS row_type,
        s.is_refund,
        s.status,
        s.customer_id,
        s.is_returning_customer,
        DATE(CASE st.date_type
                 WHEN 'date_created'   THEN s.date_created_local
                 WHEN 'date_completed' THEN s.date_completed_local
                 ELSE s.date_paid_local
             END) AS date,
        s.num_items_sold,
        s.total_sales,
        s.tax_total,
        s.shipping_total,
        s.net_total,
        -- Coupons only on the order itself; a refund does not give a coupon back.
        CASE WHEN s.is_refund THEN 0 ELSE COALESCE(oc.coupon_amount, 0) END AS coupon_amount
    FROM {{staging.woocommerce.order_stats}} s
    JOIN settings st USING (woocommerce_store)
    LEFT JOIN order_coupons oc
           ON oc.woocommerce_store = s.woocommerce_store
          AND oc.order_id          = s.order_id
    WHERE s.status NOT IN UNNEST(st.excluded_statuses)
)

SELECT
    date,
    woocommerce_store,
    order_id,
    row_type,
    ANY_VALUE(currency)              AS currency,
    -- Refund rows copy the parent's status, so this is the order's status either way.
    ANY_VALUE(status)                AS order_status,
    ANY_VALUE(customer_id)           AS customer_id,
    LOGICAL_OR(is_returning_customer) AS is_returning_customer,

    -- One per order, on its SALE row. Sum over any window for "Orders"; it is the
    -- denominator of Analytics' average order value.
    COUNTIF(NOT is_refund)           AS orders,
    -- Net of refunded items on RETURN rows (they are negative), as in Analytics.
    SUM(num_items_sold)              AS items_sold,

    -- The sales equation. Discounts and returns are negative, so
    -- net_sales = gross_sales + discounts + returns is plain addition.
    -- net_total is the order after coupons, before tax and shipping.
    ROUND(SUM(CASE WHEN NOT is_refund THEN net_total + coupon_amount ELSE 0 END), 2) AS gross_sales,
    ROUND(-1 * SUM(coupon_amount), 2)                                               AS discounts,
    ROUND(SUM(CASE WHEN is_refund THEN net_total ELSE 0 END), 2)                     AS returns,
    ROUND(SUM(net_total), 2)                                                         AS net_sales,

    -- No row type filter: refunded shipping and tax reduce these on the refund day.
    ROUND(SUM(shipping_total), 2) AS shipping,
    ROUND(SUM(tax_total), 2)      AS taxes,

    -- Analytics' "Total sales": the order total including tax and shipping, net of
    -- refunds.
    ROUND(SUM(total_sales), 2)    AS total_sales,

    -- The whole refund including its tax and shipping. Recent WooCommerce versions
    -- show this (as a positive number) as "Refunds"; older ones show the net
    -- part only, which is `returns` above.
    ROUND(SUM(CASE WHEN is_refund THEN net_total + tax_total + shipping_total ELSE 0 END), 2)
        AS returns_incl_tax_and_shipping
FROM stats
WHERE date IS NOT NULL
GROUP BY date, woocommerce_store, order_id, row_type
