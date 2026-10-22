-- staging.adobe_commerce.sales_order
-- One row per order, as Adobe Commerce (Magento) keeps it: a single row whose
-- amount columns are updated in place as the order is invoiced, refunded or
-- cancelled. There is no event history here; *_refunded and *_canceled are
-- running totals as of the last sync.
--
-- Money: the base_* columns, in the website's base currency, which is what the
-- admin reports use (they then multiply by base_to_global_rate). Order currency
-- columns are not used. NULL amounts become 0 so core can add them.
--
-- Signs, as Magento stores them: base_discount_amount is NEGATIVE on the order;
-- base_discount_canceled, base_discount_refunded and everything else are positive.
-- They are normalised here so that every *_discount_* column is a positive
-- magnitude; core applies the sign once.
--
-- Time: created_at is a MySQL TIMESTAMP and arrives as real UTC.
--
-- Single store. To add another, UNION ALL a second block below pointing at that
-- store's connector with a different adobe_commerce_store label.

SELECT
    'store_1'                                          AS adobe_commerce_store,
    CAST(entity_id AS INT64)                           AS order_id,
    CAST(increment_id AS STRING)                       AS order_number,
    CAST(store_id AS INT64)                            AS store_id,
    CAST(state AS STRING)                              AS state,
    CAST(status AS STRING)                             AS status,
    CAST(customer_id AS INT64)                         AS customer_id,
    COALESCE(CAST(customer_is_guest AS INT64), 0) = 1  AS is_guest,
    CAST(customer_group_id AS INT64)                   AS customer_group_id,
    LOWER(NULLIF(TRIM(CAST(customer_email AS STRING)), '')) AS customer_email,
    NULLIF(TRIM(CAST(coupon_code AS STRING)), '')      AS coupon_code,
    CAST(shipping_method AS STRING)                    AS shipping_method,
    CAST(created_at AS TIMESTAMP)                      AS created_at,
    CAST(updated_at AS TIMESTAMP)                      AS updated_at,
    CAST(base_currency_code AS STRING)                 AS base_currency_code,
    CAST(global_currency_code AS STRING)               AS global_currency_code,
    CAST(order_currency_code AS STRING)                AS order_currency_code,
    -- Magento's own reports treat a missing rate as 0, which silently drops the
    -- order from every total. 1 is the right value for a single-currency store and
    -- the safer default for any other.
    COALESCE(CAST(base_to_global_rate AS NUMERIC), 1)  AS base_to_global_rate,

    COALESCE(CAST(base_subtotal AS NUMERIC), 0)            AS base_subtotal,
    COALESCE(CAST(base_subtotal_canceled AS NUMERIC), 0)   AS base_subtotal_canceled,
    COALESCE(CAST(base_subtotal_refunded AS NUMERIC), 0)   AS base_subtotal_refunded,
    ABS(COALESCE(CAST(base_discount_amount AS NUMERIC), 0))   AS base_discount_amount,
    ABS(COALESCE(CAST(base_discount_canceled AS NUMERIC), 0)) AS base_discount_canceled,
    ABS(COALESCE(CAST(base_discount_invoiced AS NUMERIC), 0)) AS base_discount_invoiced,
    ABS(COALESCE(CAST(base_discount_refunded AS NUMERIC), 0)) AS base_discount_refunded,
    COALESCE(CAST(base_shipping_amount AS NUMERIC), 0)     AS base_shipping_amount,
    COALESCE(CAST(base_shipping_canceled AS NUMERIC), 0)   AS base_shipping_canceled,
    COALESCE(CAST(base_shipping_invoiced AS NUMERIC), 0)   AS base_shipping_invoiced,
    COALESCE(CAST(base_shipping_refunded AS NUMERIC), 0)   AS base_shipping_refunded,
    COALESCE(CAST(base_tax_amount AS NUMERIC), 0)          AS base_tax_amount,
    COALESCE(CAST(base_tax_canceled AS NUMERIC), 0)        AS base_tax_canceled,
    COALESCE(CAST(base_tax_invoiced AS NUMERIC), 0)        AS base_tax_invoiced,
    COALESCE(CAST(base_tax_refunded AS NUMERIC), 0)        AS base_tax_refunded,
    COALESCE(CAST(base_adjustment_positive AS NUMERIC), 0) AS base_adjustment_positive,
    COALESCE(CAST(base_adjustment_negative AS NUMERIC), 0) AS base_adjustment_negative,
    COALESCE(CAST(base_grand_total AS NUMERIC), 0)         AS base_grand_total,
    COALESCE(CAST(base_total_canceled AS NUMERIC), 0)      AS base_total_canceled,
    COALESCE(CAST(base_total_invoiced AS NUMERIC), 0)      AS base_total_invoiced,
    COALESCE(CAST(base_total_invoiced_cost AS NUMERIC), 0) AS base_total_invoiced_cost,
    COALESCE(CAST(base_total_paid AS NUMERIC), 0)          AS base_total_paid,
    COALESCE(CAST(base_total_refunded AS NUMERIC), 0)      AS base_total_refunded
FROM {{raw.adobe_commerce.sales_order}}
-- An incremental sync can land a changed order more than once; keep the latest.
QUALIFY ROW_NUMBER() OVER (PARTITION BY entity_id ORDER BY _weld_synced DESC) = 1
