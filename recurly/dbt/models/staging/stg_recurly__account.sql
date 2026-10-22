-- stg_recurly__account
-- Thin wrapper over raw `account`. One row per account (Recurly's customer).
-- Only descriptive columns; no contact details beyond the name.
-- Deleted accounts are kept, flagged: their invoices still count as revenue.

SELECT
    CAST(id AS STRING)                                          AS account_id,
    -- Your own identifier for the customer, set when the account was created.
    CAST(code AS STRING)                                        AS account_code,
    CAST(company AS STRING)                                     AS company,
    COALESCE(
        NULLIF(TRIM(CAST(company AS STRING)), ''),
        NULLIF(TRIM(CONCAT(COALESCE(CAST(first_name AS STRING), ''), ' ',
                           COALESCE(CAST(last_name AS STRING), ''))), ''),
        CAST(code AS STRING)
    )                                                           AS customer_name,
    LOWER(CAST(state AS STRING))                                AS state,
    CAST(address_country AS STRING)                             AS country,
    CAST(created_at AS TIMESTAMP)                               AS created_at,
    CAST(deleted_at AS TIMESTAMP)                               AS deleted_at
FROM {{ source('recurly', 'account') }}
QUALIFY ROW_NUMBER() OVER (PARTITION BY id ORDER BY _weld_synced DESC) = 1
