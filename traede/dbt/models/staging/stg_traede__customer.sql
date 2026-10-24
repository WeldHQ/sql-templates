-- stg_traede__customer
-- Thin wrapper over raw `customer`. One row per customer (a retailer or other
-- buyer account in Traede).

SELECT
    'account_1'                                          AS traede_account,
    CAST(id AS STRING)                                   AS customer_id,
    NULLIF(TRIM(CAST(customer_number AS STRING)), '')    AS customer_number,
    NULLIF(TRIM(CAST(name AS STRING)), '')               AS customer_name,
    UPPER(NULLIF(TRIM(CAST(country AS STRING)), ''))     AS customer_country,
    UPPER(NULLIF(TRIM(CAST(currency AS STRING)), ''))    AS customer_currency,
    CAST(created_at AS TIMESTAMP)                        AS created_at
FROM {{ source('traede', 'customer') }}
