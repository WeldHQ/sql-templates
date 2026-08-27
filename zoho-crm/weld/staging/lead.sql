-- staging.zoho_crm.lead
-- Thin wrapper over raw `lead`. Casts, renames, builds full_name.
--
-- Leads are a terminal island in this schema. The connector syncs no
-- Converted_Account / Converted_Contact / Converted_Deal fields, so a lead cannot
-- be followed into the deal it became. Lead reporting here is volume and status
-- only - see the README before promising a lead-to-deal conversion rate.

SELECT
    'org_1'                                 AS zoho_org,
    CAST(id AS STRING)                      AS lead_id,
    CAST(first_name AS STRING)              AS first_name,
    CAST(last_name AS STRING)               AS last_name,
    NULLIF(TRIM(CONCAT(
        COALESCE(CAST(first_name AS STRING), ''), ' ',
        COALESCE(CAST(last_name AS STRING), '')
    )), '')                                 AS full_name,
    LOWER(NULLIF(TRIM(CAST(email AS STRING)), '')) AS email,
    NULLIF(TRIM(CAST(company AS STRING)), '')      AS company,
    NULLIF(TRIM(CAST(lead_status AS STRING)), '')  AS lead_status,
    CAST(owner_id AS STRING)                AS owner_id,
    CAST(created_time AS TIMESTAMP)         AS created_time,
    CAST(modified_time AS TIMESTAMP)        AS modified_time
FROM {{raw.zoho_crm.lead}}
