-- stg_hubspot_v2__company
-- Thin wrapper over raw `company`. Casts, renames, drops archived companies.
-- Grain: one row per company.

SELECT
    'portal_1'                                              AS hubspot_portal,
    CAST(company_id AS STRING)                              AS company_id,
    NULLIF(TRIM(properties_name), '')                       AS company_name,
    LOWER(NULLIF(TRIM(properties_domain), ''))              AS domain,
    NULLIF(TRIM(properties_industry), '')                   AS industry,
    NULLIF(TRIM(properties_country), '')                    AS country,
    CAST(properties_numberofemployees AS FLOAT64)           AS number_of_employees,
    NULLIF(TRIM(properties_lifecyclestage), '')             AS lifecycle_stage,
    NULLIF(TRIM(properties_type), '')                       AS company_type,
    CAST(CAST(properties_hubspot_owner_id AS INT64) AS STRING) AS owner_id,
    CAST(CAST(properties_hs_parent_company_id AS INT64) AS STRING) AS parent_company_id,
    CAST(properties_createdate AS TIMESTAMP)                AS created_at,
    -- Last time a rep logged a call, email or meeting against the company.
    CAST(properties_notes_last_contacted AS TIMESTAMP)      AS last_contacted_at,
    -- Last time any activity was logged or edited on the company.
    CAST(properties_notes_last_updated AS TIMESTAMP)        AS last_activity_at,
    CAST(properties_notes_next_activity_date AS TIMESTAMP)  AS next_activity_at,
    NULLIF(TRIM(properties_hs_analytics_source), '')        AS original_source
FROM {{ source('hubspot_v2', 'company') }}
WHERE NOT COALESCE(archived, FALSE)
