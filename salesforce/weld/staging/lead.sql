-- staging.salesforce.lead
-- Thin wrapper over raw `lead`. Casts, renames, drops deleted records.
-- Grain: one row per lead.
--
-- Converted leads stay in Salesforce (hidden from list views, still queryable)
-- with is_converted = TRUE and the ids of the account, contact and opportunity
-- the conversion created, so conversion can be measured from this table alone.

SELECT
    'org_1'                                        AS salesforce_org,
    CAST(id AS STRING)                             AS lead_id,
    NULLIF(TRIM(CAST(company AS STRING)), '')      AS company,
    NULLIF(TRIM(CAST(status AS STRING)), '')       AS lead_status,
    NULLIF(TRIM(CAST(lead_source AS STRING)), '')  AS lead_source,
    NULLIF(TRIM(CAST(industry AS STRING)), '')     AS industry,
    NULLIF(TRIM(CAST(country AS STRING)), '')      AS country,
    CAST(owner_id AS STRING)                       AS owner_id,
    CAST(is_converted AS BOOL)                     AS is_converted,
    -- Date-only field, landed as a timestamp at midnight UTC.
    DATE(CAST(converted_date AS TIMESTAMP))        AS converted_date,
    CAST(converted_account_id AS STRING)           AS converted_account_id,
    CAST(converted_contact_id AS STRING)           AS converted_contact_id,
    CAST(converted_opportunity_id AS STRING)       AS converted_opportunity_id,
    CAST(created_date AS TIMESTAMP)                AS created_at
FROM {{raw.salesforce.lead}}
WHERE NOT COALESCE(is_deleted, FALSE)
