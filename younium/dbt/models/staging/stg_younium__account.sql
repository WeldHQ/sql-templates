-- stg_younium__account
-- One row per Younium account (customer), with Younium's current CMRR, ACV and
-- TCV for it.
--
-- Units: major units. Each metric comes in the account's currency and converted to
-- the Younium base currency; both are kept. The values are a snapshot as of the
-- last sync, not history.

SELECT
    CAST(id AS STRING)                                        AS account_id,
    CAST(account_number AS STRING)                            AS account_number,
    CAST(name AS STRING)                                      AS account_name,
    CAST(account_type AS STRING)                              AS account_type,
    CAST(parent_account_id AS STRING)                         AS parent_account_id,
    COALESCE(CAST(inactive AS BOOL), FALSE)                   AS is_inactive,
    UPPER(NULLIF(TRIM(CAST(default_invoice_address_country AS STRING)), '')) AS country,
    CAST(created AS TIMESTAMP)                                AS created_at,
    UPPER(NULLIF(TRIM(CAST(cmrr_currency_code AS STRING)), ''))      AS currency,
    UPPER(NULLIF(TRIM(CAST(cmrr_base_currency_code AS STRING)), '')) AS base_currency,
    CAST(cmrr_amount AS NUMERIC)                              AS cmrr,
    CAST(cmrr_base_currency_amount AS NUMERIC)                AS cmrr_base,
    CAST(acv_amount AS NUMERIC)                               AS acv,
    CAST(acv_base_currency_amount AS NUMERIC)                 AS acv_base,
    CAST(tcv_base_currency_amount AS NUMERIC)                 AS tcv_base
FROM {{ source('younium', 'account') }}
WHERE id IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY id ORDER BY modified DESC, _weld_synced DESC) = 1
