-- core_woocommerce__product_sales_over_time
-- Recreates WooCommerce Analytics' Products and Variations reports (items sold,
-- net sales, orders) at line grain, with the same sales equation as
-- sales_over_time.
--
-- Grain: day x store x order x line. A line is one row of wc_order_product_lookup:
-- a product line on an order (row_type SALE) or on a refund (row_type RETURN).
-- order_id is always the ORIGINAL order, so a refunded line and the line it
-- reverses share an order_id but not a line id.
--
-- Same report date and status rules as sales_over_time (read from the store's
-- analytics settings, applied through wc_order_stats), so the two agree on which
-- orders count and on which day.
--
-- Product lines only. Shipping lines, fees and order-level refund amounts that are
-- not tied to a product are not in the lookup table, so net_sales here sums to
-- less than sales_over_time.net_sales whenever a store charges fees or refunds a
-- lump sum. Discounts do tie exactly: sales_over_time takes its coupons from these
-- same lines.
--
-- Orders per product: COUNT(DISTINCT order_id) over SALE rows, which is the
-- Products report's "Orders" column. Not a column here, because a distinct count
-- does not survive being summed across days.
--
-- Names: product_name is the current catalog name; line_item_name is the name as
-- it read on the order and survives the product being renamed or deleted.
--
-- Depends on: staging.woocommerce.order_product_lookup, .order_stats,
--             .order_items, .product, .product_sku, .store_settings

WITH settings AS (
    SELECT
        woocommerce_store,
        currency,
        COALESCE(analytics_date_type, 'date_paid') AS date_type,
        ARRAY_CONCAT(
            ['wc-auto-draft', 'wc-trash'],
            COALESCE(excluded_statuses, ['wc-pending', 'wc-failed', 'wc-cancelled'])
        ) AS excluded_statuses
    FROM {{ ref('stg_woocommerce__store_settings') }}
),

-- The order (or refund) each line belongs to, with its report date. One row per
-- wc_order_stats row, so joining lines to it cannot fan out.
parents AS (
    SELECT
        s.woocommerce_store,
        s.order_id AS lookup_order_id,
        CASE WHEN s.is_refund THEN s.parent_id ELSE s.order_id END AS order_id,
        s.is_refund,
        s.status,
        st.currency,
        DATE(CASE st.date_type
                 WHEN 'date_created'   THEN s.date_created_local
                 WHEN 'date_completed' THEN s.date_completed_local
                 ELSE s.date_paid_local
             END) AS date
    FROM {{ ref('stg_woocommerce__order_stats') }} s
    JOIN settings st USING (woocommerce_store)
    WHERE s.status NOT IN UNNEST(st.excluded_statuses)
),

products AS (
    SELECT p.woocommerce_store, p.post_id, p.title, k.sku
    FROM {{ ref('stg_woocommerce__product') }} p
    LEFT JOIN {{ ref('stg_woocommerce__product_sku') }} k USING (woocommerce_store, post_id)
)

SELECT
    pa.date,
    l.woocommerce_store,
    pa.order_id,
    l.order_item_id,
    CASE WHEN pa.is_refund THEN 'RETURN' ELSE 'SALE' END AS row_type,
    pa.currency,
    pa.status                     AS order_status,
    l.customer_id,

    l.product_id,
    l.variation_id,
    pr.title                      AS product_name,
    va.title                      AS variation_name,
    oi.order_item_name            AS line_item_name,
    -- A variation's own SKU wins; WooCommerce falls back to the parent's.
    COALESCE(va.sku, pr.sku)      AS sku,

    -- Negative on RETURN lines, so the sum is items sold net of refunds.
    l.quantity                    AS items_sold,

    ROUND(CASE WHEN pa.is_refund THEN 0 ELSE l.net_revenue + l.coupon_amount END, 2) AS gross_sales,
    ROUND(CASE WHEN pa.is_refund THEN 0 ELSE -1 * l.coupon_amount END, 2)            AS discounts,
    ROUND(CASE WHEN pa.is_refund THEN l.net_revenue ELSE 0 END, 2)                    AS returns,
    -- Analytics' "Net sales" for a product.
    ROUND(l.net_revenue, 2)       AS net_sales,

    -- Tax on the line, and the order's shipping (and its tax) allocated across its
    -- product lines by WooCommerce.
    ROUND(l.tax_amount, 2)        AS taxes,
    ROUND(l.shipping_amount, 2)   AS shipping,
    ROUND(l.shipping_tax_amount, 2) AS shipping_taxes
FROM {{ ref('stg_woocommerce__order_product_lookup') }} l
JOIN parents pa
  ON pa.woocommerce_store = l.woocommerce_store
 AND pa.lookup_order_id   = l.order_id
LEFT JOIN products pr
  ON pr.woocommerce_store = l.woocommerce_store
 AND pr.post_id           = l.product_id
LEFT JOIN products va
  ON va.woocommerce_store = l.woocommerce_store
 AND va.post_id           = l.variation_id
LEFT JOIN {{ ref('stg_woocommerce__order_items') }} oi
  ON oi.woocommerce_store = l.woocommerce_store
 AND oi.order_item_id     = l.order_item_id
WHERE pa.date IS NOT NULL
