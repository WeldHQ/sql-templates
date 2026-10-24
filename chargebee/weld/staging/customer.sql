-- staging.chargebee.customer
-- Thin wrapper over raw `customer`. One row per customer, deleted customers
-- dropped. Only descriptive columns; no contact details beyond the name.

SELECT
    CAST(id AS STRING)                                          AS customer_id,
    CAST(company AS STRING)                                     AS company,
    COALESCE(
        NULLIF(TRIM(CAST(company AS STRING)), ''),
        NULLIF(TRIM(CONCAT(COALESCE(CAST(first_name AS STRING), ''), ' ',
                           COALESCE(CAST(last_name AS STRING), ''))), '')
    )                                                           AS customer_name,
    UPPER(CAST(preferred_currency_code AS STRING))              AS preferred_currency,
    CAST(billing_address_country AS STRING)                     AS billing_country,
    CAST(created_at AS TIMESTAMP)                               AS created_at
FROM {{raw.chargebee.customer}}
WHERE COALESCE(CAST(deleted AS BOOL), FALSE) = FALSE
QUALIFY ROW_NUMBER() OVER (PARTITION BY id ORDER BY _weld_synced DESC) = 1
