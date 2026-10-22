-- staging.bigcommerce.order
-- Thin wrapper over raw `order`. Casts, renames, blanks to NULL. No other logic:
-- which statuses count as a sale is a reporting decision and lives in core.
--
-- Timestamps are UTC. Money columns are in the order's own currency (currency_code);
-- BigCommerce reports them both tax-exclusive and tax-inclusive, so no tax maths is
-- needed downstream.
--
-- Single store. To add another, UNION ALL a second block below pointing at that
-- store's connector with a different bigcommerce_store label. Order IDs are only
-- unique within a store.

SELECT
    'store_1'                                                   AS bigcommerce_store,
    CAST(id AS INT64)                                           AS order_id,
    CAST(customer_id AS INT64)                                  AS customer_id,
    CAST(channel_id AS INT64)                                   AS channel_id,
    CAST(date_created AS TIMESTAMP)                             AS created_at,
    CAST(date_modified AS TIMESTAMP)                            AS modified_at,
    CAST(date_shipped AS TIMESTAMP)                             AS shipped_at,

    -- status_id is the stable key; status is the label, which a merchant can
    -- rename. BigCommerce's fixed IDs: 0 Incomplete, 1 Pending, 2 Shipped,
    -- 3 Partially Shipped, 4 Refunded, 5 Cancelled, 6 Declined, 7 Awaiting Payment,
    -- 8 Awaiting Pickup, 9 Awaiting Shipment, 10 Completed, 11 Awaiting Fulfillment,
    -- 12 Manual Verification Required, 13 Disputed, 14 Partially Refunded.
    CAST(status_id AS INT64)                                    AS status_id,
    NULLIF(TRIM(CAST(status AS STRING)), '')                    AS status,
    NULLIF(TRIM(CAST(custom_status AS STRING)), '')             AS custom_status,
    NULLIF(TRIM(CAST(payment_status AS STRING)), '')            AS payment_status,
    NULLIF(TRIM(CAST(payment_method AS STRING)), '')            AS payment_method,
    LOWER(NULLIF(TRIM(CAST(order_source AS STRING)), ''))       AS order_source,
    COALESCE(CAST(is_deleted AS BOOL), FALSE)                   AS is_deleted,
    COALESCE(CAST(order_is_digital AS BOOL), FALSE)             AS is_digital,

    UPPER(NULLIF(TRIM(CAST(currency_code AS STRING)), ''))          AS currency_code,
    UPPER(NULLIF(TRIM(CAST(default_currency_code AS STRING)), ''))  AS default_currency_code,
    CAST(store_default_to_transactional_exchange_rate AS FLOAT64)   AS store_default_to_transactional_exchange_rate,

    UPPER(NULLIF(TRIM(CAST(billing_address_country_iso2 AS STRING)), '')) AS billing_country_code,
    UPPER(NULLIF(TRIM(CAST(geoip_country_iso2 AS STRING)), ''))           AS geoip_country_code,

    -- Products before discounts, tax excluded.
    CAST(subtotal_ex_tax AS NUMERIC)                            AS subtotal_ex_tax,
    CAST(shipping_cost_ex_tax AS NUMERIC)                       AS shipping_cost_ex_tax,
    CAST(handling_cost_ex_tax AS NUMERIC)                       AS handling_cost_ex_tax,
    CAST(wrapping_cost_ex_tax AS NUMERIC)                       AS wrapping_cost_ex_tax,
    CAST(total_ex_tax AS NUMERIC)                               AS total_ex_tax,
    CAST(total_tax AS NUMERIC)                                  AS total_tax,
    CAST(total_inc_tax AS NUMERIC)                              AS total_inc_tax,

    -- As reported. Kept for reference only: core derives discounts from the totals
    -- instead, see core.bigcommerce.sales_over_time.
    CAST(discount_amount AS NUMERIC)                            AS discount_amount,
    CAST(coupon_discount AS NUMERIC)                            AS coupon_discount,

    -- Payment methods, not discounts: a gift certificate or store credit pays for
    -- part of the order and does not reduce what was sold.
    CAST(gift_certificate_amount AS NUMERIC)                    AS gift_certificate_amount,
    CAST(store_credit_amount AS NUMERIC)                        AS store_credit_amount,
    CAST(refunded_amount AS NUMERIC)                            AS refunded_amount,

    CAST(items_total AS INT64)                                  AS items_total,
    CAST(items_shipped AS INT64)                                AS items_shipped
FROM {{raw.bigcommerce.order}}
