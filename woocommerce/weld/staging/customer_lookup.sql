-- staging.woocommerce.customer_lookup
-- One row per customer as WooCommerce Analytics sees them: registered accounts AND
-- guest checkouts (user_id is NULL for a guest). customer_id is the key
-- wc_order_stats.customer_id points at; it is not the WordPress user id.
-- Location is the customer's latest billing address, not the address on each order.

SELECT
    'store_1'                                          AS woocommerce_store,
    CAST(customer_id AS INT64)                         AS customer_id,
    CAST(user_id AS INT64)                             AS user_id,
    CAST(user_id AS INT64) IS NULL                     AS is_guest,
    NULLIF(TRIM(CAST(username AS STRING)), '')         AS username,
    NULLIF(TRIM(CAST(first_name AS STRING)), '')       AS first_name,
    NULLIF(TRIM(CAST(last_name AS STRING)), '')        AS last_name,
    LOWER(NULLIF(TRIM(CAST(email AS STRING)), ''))     AS email,
    NULLIF(TRIM(CAST(country AS STRING)), '')          AS country,
    NULLIF(TRIM(CAST(state AS STRING)), '')            AS state,
    NULLIF(TRIM(CAST(city AS STRING)), '')             AS city,
    NULLIF(TRIM(CAST(postcode AS STRING)), '')         AS postcode,
    DATETIME(CAST(date_registered AS TIMESTAMP), 'UTC')  AS date_registered_local,
    DATETIME(CAST(date_last_active AS TIMESTAMP), 'UTC') AS date_last_active_local
FROM {{raw.woocommerce.wp_wc_customer_lookup}}
QUALIFY ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY _weld_synced DESC) = 1
