-- staging.salesforce_commerce_cloud.order
-- Thin wrapper over raw `order`: one row per order, header money only. Casts,
-- renames, blanks to NULL. Status filtering is a reporting decision and lives in
-- core.
--
-- TIMESTAMPS, DEFENSIVELY. The connector declares creation_date, place_date and
-- last_modified as millisecond timestamps, but they can land either as TIMESTAMP or
-- as an integer of epoch milliseconds depending on the destination. The expression
-- below goes through STRING so it accepts both, and returns UTC.
--
-- TAXATION. Each site prices either gross (prices include tax, as in most of
-- Europe) or net (tax added on top, as in the US). `taxation` says which, and it
-- changes what product_total and order_total contain; core handles both.
--
-- Single instance. To add another, UNION ALL a second block below with a different
-- sfcc_instance label.

SELECT
    'instance_1'                                                    AS sfcc_instance,
    CAST(order_no AS STRING)                                        AS order_no,
    NULLIF(TRIM(CAST(site_id AS STRING)), '')                       AS site_id,

    COALESCE(SAFE.TIMESTAMP_MILLIS(SAFE_CAST(CAST(creation_date AS STRING) AS INT64)),
             SAFE_CAST(CAST(creation_date AS STRING) AS TIMESTAMP))  AS created_at,
    COALESCE(SAFE.TIMESTAMP_MILLIS(SAFE_CAST(CAST(place_date AS STRING) AS INT64)),
             SAFE_CAST(CAST(place_date AS STRING) AS TIMESTAMP))     AS placed_at,
    COALESCE(SAFE.TIMESTAMP_MILLIS(SAFE_CAST(CAST(last_modified AS STRING) AS INT64)),
             SAFE_CAST(CAST(last_modified AS STRING) AS TIMESTAMP))  AS modified_at,

    -- created, new, open, completed, cancelled, replaced, failed
    LOWER(NULLIF(TRIM(CAST(status AS STRING)), ''))                 AS status,
    LOWER(NULLIF(TRIM(CAST(payment_status AS STRING)), ''))         AS payment_status,
    LOWER(NULLIF(TRIM(CAST(shipping_status AS STRING)), ''))        AS shipping_status,
    LOWER(NULLIF(TRIM(CAST(confirmation_status AS STRING)), ''))    AS confirmation_status,
    LOWER(NULLIF(TRIM(CAST(export_status AS STRING)), ''))          AS export_status,
    LOWER(NULLIF(TRIM(CAST(taxation AS STRING)), ''))               AS taxation,
    UPPER(NULLIF(TRIM(CAST(currency AS STRING)), ''))               AS currency,
    NULLIF(TRIM(CAST(customer_locale AS STRING)), '')               AS customer_locale,
    NULLIF(TRIM(CAST(created_by AS STRING)), '')                    AS created_by,

    NULLIF(TRIM(CAST(customer_info_customer_id AS STRING)), '')     AS customer_id,
    COALESCE(CAST(customer_info_guest AS BOOL), FALSE)              AS is_guest,
    UPPER(NULLIF(TRIM(CAST(billing_address_country_code AS STRING)), '')) AS billing_country_code,

    -- Products after item-level adjustments, before order-level ones.
    CAST(product_sub_total AS NUMERIC)                              AS product_sub_total,
    -- Products after item- and order-level adjustments.
    CAST(product_total AS NUMERIC)                                  AS product_total,
    -- Shipping after shipping adjustments.
    CAST(shipping_total AS NUMERIC)                                 AS shipping_total,
    CAST(tax_total AS NUMERIC)                                      AS tax_total,
    CAST(adjusted_merchandize_total_tax AS NUMERIC)                 AS merchandise_tax,
    CAST(adjusted_shipping_total_tax AS NUMERIC)                    AS shipping_tax,
    CAST(order_total AS NUMERIC)                                    AS order_total
FROM {{raw.salesforce_commerce_cloud.order}}
