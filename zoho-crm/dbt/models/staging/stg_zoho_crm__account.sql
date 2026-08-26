-- stg_zoho_crm__account
-- Thin wrapper over raw `account`. Casts, renames, normalises blanks to NULL.
--
-- Single Zoho org. To add another, UNION ALL a second block below pointing at that
-- org's connector with a different zoho_org label.

SELECT
    'org_1'                                 AS zoho_org,
    CAST(id AS STRING)                      AS account_id,
    NULLIF(TRIM(CAST(account_name AS STRING)), '') AS account_name,
    NULLIF(TRIM(CAST(industry AS STRING)), '')     AS industry,
    NULLIF(TRIM(CAST(phone AS STRING)), '')        AS phone,
    NULLIF(TRIM(CAST(website AS STRING)), '')      AS website,
    -- Zoho flattens its lookup fields into _id / _name / _email triples. Keep the
    -- id for joining and drop the denormalised name - stg_zoho_crm__user is the
    -- single source of truth for what a user is called, so a rep who is renamed in
    -- Zoho does not leave stale labels scattered across every module.
    CAST(owner_id AS STRING)                AS owner_id,
    CAST(created_time AS TIMESTAMP)         AS created_time,
    CAST(modified_time AS TIMESTAMP)        AS modified_time
FROM {{ source('zoho_crm', 'account') }}
