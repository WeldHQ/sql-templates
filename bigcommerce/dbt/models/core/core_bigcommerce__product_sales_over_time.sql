-- core_bigcommerce__product_sales_over_time
-- The sales equation per order line, with
-- product refunds on the day they were made.
--
-- Grain: day x store x order x order line x row type (SALE or RETURN).
-- Currency: the order's own. Timezone: staging.bigcommerce.store.report_timezone.
--
-- Depends on: staging.bigcommerce.order, .order_line_item,
--             .order_line_item_discount, .refund, .refund_line_item,
--             .refund_payment, .store
--
-- RECONCILES TO sales_over_time ON SALE ROWS. Line discounts come from
-- order_line_item_discount. Whatever part of the order's discount is not attached
-- to a line (a manual order discount, for instance) is spread across the order's
-- lines in proportion to their gross value, so net_sales here sums to net_sales in
-- sales_over_time for every order. tests/assert_product_reconciles_to_sales.sql
-- checks it.
--
-- RETURN ROWS ARE AN ESTIMATE, AND DO NOT RECONCILE. BigCommerce refunds products
-- by quantity and does not store the money per line, so a returned unit is valued
-- at the line's net unit price, tax excluded (is_return_value_estimated = TRUE).
-- Where a PRODUCT refund line carries an explicit requested_amount and no
-- quantity, that amount is used as given. Refunds of shipping, handling or a
-- lump sum against the whole order have no product and are only in
-- sales_over_time.
--
-- Same order filter as sales_over_time: Incomplete, Cancelled, Declined and
-- archived orders are dropped.

WITH store AS (
    SELECT bigcommerce_store, report_timezone
    FROM {{ ref('stg_bigcommerce__store') }}
),

orders AS (
    SELECT
        o.bigcommerce_store,
        o.order_id,
        o.created_at,
        o.currency_code,
        o.status_id,
        o.status,
        o.subtotal_ex_tax,
        o.total_ex_tax - o.subtotal_ex_tax
            - COALESCE(o.shipping_cost_ex_tax, 0)
            - COALESCE(o.handling_cost_ex_tax, 0)
            - COALESCE(o.wrapping_cost_ex_tax, 0)      AS order_discounts,
        s.report_timezone
    FROM {{ ref('stg_bigcommerce__order') }} o
    JOIN store s USING (bigcommerce_store)
    WHERE COALESCE(o.status_id, -1) NOT IN (0, 5, 6)
      AND NOT o.is_deleted
),

line_discounts AS (
    SELECT bigcommerce_store, order_id, order_line_item_id, SUM(discount_amount) AS line_discount
    FROM {{ ref('stg_bigcommerce__order_line_item_discount') }}
    GROUP BY 1, 2, 3
),

lines AS (
    SELECT
        l.*,
        COALESCE(d.line_discount, 0)                   AS line_discount,
        o.created_at,
        o.currency_code,
        o.status_id,
        o.status,
        o.order_discounts,
        o.report_timezone,
        SUM(COALESCE(l.total_ex_tax, 0)) OVER w        AS order_gross,
        SUM(COALESCE(d.line_discount, 0)) OVER w       AS order_line_discounts,
        COUNT(*) OVER w                                AS order_line_count
    FROM {{ ref('stg_bigcommerce__order_line_item') }} l
    JOIN orders o USING (bigcommerce_store, order_id)
    LEFT JOIN line_discounts d USING (bigcommerce_store, order_id, order_line_item_id)
    WINDOW w AS (PARTITION BY l.bigcommerce_store, l.order_id)
),

priced AS (
    SELECT
        *,
        -- Order-level discount not attached to any line, spread by gross value
        -- (evenly when the order has no gross at all).
        (order_discounts - order_line_discounts)
            * COALESCE(SAFE_DIVIDE(COALESCE(total_ex_tax, 0), NULLIF(order_gross, 0)),
                       CAST(1 AS NUMERIC) / order_line_count)           AS allocated_order_discount
    FROM lines
),

sale_rows AS (
    SELECT
        DATE(created_at, report_timezone)              AS date,
        bigcommerce_store,
        order_id,
        order_line_item_id,
        'SALE'                                         AS row_type,
        COALESCE(total_ex_tax, 0)                      AS gross_sales,
        line_discount + allocated_order_discount       AS discounts,
        CAST(0 AS NUMERIC)                             AS returns,
        COALESCE(total_tax, 0)                         AS taxes,
        quantity                                       AS quantity_ordered,
        0                                              AS quantity_returned,
        unit_cost * quantity                           AS cost_of_goods,
        FALSE                                          AS is_return_value_estimated
    FROM priced
),

kept_refunds AS (
    SELECT r.bigcommerce_store, r.refund_id, r.order_id, r.created_at
    FROM {{ ref('stg_bigcommerce__refund') }} r
    LEFT JOIN (
        SELECT bigcommerce_store, refund_id
        FROM {{ ref('stg_bigcommerce__refund_payment') }}
        GROUP BY bigcommerce_store, refund_id
        HAVING LOGICAL_AND(is_declined)
    ) d USING (bigcommerce_store, refund_id)
    WHERE d.refund_id IS NULL
),

return_rows AS (
    SELECT
        DATE(r.created_at, p.report_timezone)          AS date,
        p.bigcommerce_store,
        p.order_id,
        p.order_line_item_id,
        'RETURN'                                       AS row_type,
        CAST(0 AS NUMERIC)                             AS gross_sales,
        CAST(0 AS NUMERIC)                             AS discounts,
        -SUM(
            CASE
                WHEN rl.quantity IS NULL AND rl.requested_amount IS NOT NULL
                    THEN rl.requested_amount
                ELSE rl.quantity
                     * SAFE_DIVIDE(COALESCE(p.total_ex_tax, 0) + p.line_discount + p.allocated_order_discount,
                                   NULLIF(p.quantity, 0))
            END
        )                                              AS returns,
        CAST(0 AS NUMERIC)                             AS taxes,
        0                                              AS quantity_ordered,
        SUM(COALESCE(rl.quantity, 0))                  AS quantity_returned,
        CAST(NULL AS NUMERIC)                          AS cost_of_goods,
        LOGICAL_OR(rl.quantity IS NOT NULL)            AS is_return_value_estimated
    FROM {{ ref('stg_bigcommerce__refund_line_item') }} rl
    JOIN kept_refunds r USING (bigcommerce_store, refund_id)
    JOIN priced p
      ON p.bigcommerce_store = rl.bigcommerce_store
     AND p.order_id = r.order_id
     AND p.order_line_item_id = rl.item_id
    WHERE rl.item_type = 'PRODUCT'
    GROUP BY 1, 2, 3, 4
),

unioned AS (
    SELECT * FROM sale_rows
    UNION ALL
    SELECT * FROM return_rows
)

SELECT
    u.date,
    u.bigcommerce_store,
    u.order_id,
    u.order_line_item_id,
    u.row_type,
    p.currency_code,
    p.status_id,
    p.status,
    DATE(p.created_at, p.report_timezone)              AS order_date,
    p.product_id,
    p.variant_id,
    p.sku,
    p.product_name,
    p.brand,
    p.line_type,
    p.is_bundled_product,

    u.gross_sales,
    u.discounts,
    u.returns,
    u.gross_sales + u.discounts + u.returns            AS net_sales,
    u.taxes,
    u.quantity_ordered,
    u.quantity_returned,
    -- Cost price at the time of the order, on SALE rows. BigCommerce stores 0 when
    -- no cost price was set on the product, so a zero here usually means unknown
    -- rather than free.
    u.cost_of_goods,
    u.is_return_value_estimated
FROM unioned u
JOIN priced p USING (bigcommerce_store, order_id, order_line_item_id)
