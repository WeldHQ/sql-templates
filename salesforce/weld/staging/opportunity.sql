-- staging.salesforce.opportunity
-- Thin wrapper over raw `opportunity`. Casts, renames, drops deleted records.
-- Grain: one row per opportunity.
--
-- The connector reads with Salesforce's queryAll, so records in the recycle bin
-- arrive with is_deleted = TRUE. They are dropped here.
--
-- CURRENCY. Salesforce adds CurrencyIsoCode to every object only when multi-currency
-- is enabled for the org, and the connector syncs exactly the fields the org has.
-- In a single-currency org the column does not exist, so this model emits NULL
-- and every amount is in the org's currency. In a multi-currency org, amount is in
-- each opportunity's own currency: swap the NULL below for the commented line, and
-- the core models will keep currencies apart instead of adding them together.
--
-- Standard fields only. Custom fields arrive as snake_case columns ending in `_c`
-- (Deal_Type__c lands as deal_type_c); add the ones you need here.
--
-- Single org. To add another, UNION ALL a second block pointing at that org's
-- connector with a different salesforce_org label.

SELECT
    'org_1'                                        AS salesforce_org,
    CAST(id AS STRING)                             AS opportunity_id,
    NULLIF(TRIM(CAST(name AS STRING)), '')         AS opportunity_name,
    CAST(account_id AS STRING)                     AS account_id,
    CAST(owner_id AS STRING)                       AS owner_id,
    NULLIF(TRIM(CAST(stage_name AS STRING)), '')   AS stage_name,
    NULLIF(TRIM(CAST(type AS STRING)), '')         AS opportunity_type,
    NULLIF(TRIM(CAST(lead_source AS STRING)), '')  AS lead_source,
    CAST(forecast_category_name AS STRING)         AS forecast_category,
    CAST(is_closed AS BOOL)                        AS is_closed,
    CAST(is_won AS BOOL)                           AS is_won,
    CAST(amount AS FLOAT64)                        AS amount,
    -- Salesforce computes this as amount x probability.
    CAST(expected_revenue AS FLOAT64)              AS expected_revenue,
    CAST(probability AS FLOAT64)                   AS probability_percent,
    CAST(NULL AS STRING)                           AS currency_iso_code,
    -- CAST(currency_iso_code AS STRING)           AS currency_iso_code,
    -- Date-only field, landed as a timestamp at midnight UTC.
    DATE(CAST(close_date AS TIMESTAMP))            AS close_date,
    CAST(created_date AS TIMESTAMP)                AS created_at,
    CAST(last_modified_date AS TIMESTAMP)          AS last_modified_at,
    DATE(CAST(last_activity_date AS TIMESTAMP))    AS last_activity_date
FROM {{raw.salesforce.opportunity}}
WHERE NOT COALESCE(is_deleted, FALSE)
