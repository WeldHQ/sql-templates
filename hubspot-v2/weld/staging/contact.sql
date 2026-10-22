-- staging.hubspot_v2.contact
-- Thin wrapper over raw `contact`. Casts, renames, drops archived contacts.
-- Grain: one row per contact.
--
-- associated_company_id is HubSpot's primary company for the contact, maintained
-- by HubSpot itself, so counting contacts per company from it never double counts a
-- contact associated with several companies.

SELECT
    'portal_1'                                              AS hubspot_portal,
    CAST(contact_id AS STRING)                              AS contact_id,
    LOWER(NULLIF(TRIM(properties_email), ''))               AS email,
    NULLIF(TRIM(properties_lifecyclestage), '')             AS lifecycle_stage,
    NULLIF(TRIM(properties_hs_lead_status), '')             AS lead_status,
    CAST(CAST(properties_associatedcompanyid AS INT64) AS STRING) AS associated_company_id,
    CAST(CAST(properties_hubspot_owner_id AS INT64) AS STRING) AS owner_id,
    CAST(properties_createdate AS TIMESTAMP)                AS created_at,
    CAST(properties_notes_last_contacted AS TIMESTAMP)      AS last_contacted_at,
    NULLIF(TRIM(properties_hs_analytics_source), '')        AS original_source
FROM {{raw.hubspot_v2.contact}}
WHERE NOT COALESCE(archived, FALSE)
