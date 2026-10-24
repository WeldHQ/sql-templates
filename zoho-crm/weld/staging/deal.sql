-- staging.zoho_crm.deal
-- Thin wrapper over raw `deal`. Casts, renames, normalises blanks. Stage
-- classification is business logic and lives in core.zoho_crm.deal_pipeline.
--
-- ACCOUNT KEY: as on contact, Zoho's lookup is called Account_Name, so the raw
-- column is `account_name_id`. It holds the account's id and is renamed here.
--
-- WHAT IS NOT HERE, because the connector does not sync it: no is_won / is_closed
-- boolean, no probability, no expected_revenue, no currency, no lead_source, no
-- contact_id, no campaign_id and no pipeline name. Won/lost has to be derived from
-- the stage string, and amount is in whatever single currency the org reports in.

SELECT
    'org_1'                                 AS zoho_org,
    CAST(id AS STRING)                      AS deal_id,
    NULLIF(TRIM(CAST(deal_name AS STRING)), '') AS deal_name,
    NULLIF(TRIM(CAST(stage AS STRING)), '')     AS stage,
    -- No currency column exists on the stream, so this is org-reporting currency.
    -- A multi-currency Zoho org cannot be summed correctly from this connector.
    CAST(amount AS NUMERIC)                 AS amount,
    CAST(closing_date AS DATE)              AS closing_date,
    CAST(account_name_id AS STRING)         AS account_id,
    CAST(owner_id AS STRING)                AS owner_id,
    CAST(created_time AS TIMESTAMP)         AS created_time,
    CAST(modified_time AS TIMESTAMP)        AS modified_time
FROM {{raw.zoho_crm.deal}}
