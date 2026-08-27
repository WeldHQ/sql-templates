-- staging.zoho_crm.user
-- Thin wrapper over raw `user`. Casts, renames, derives is_active. No other logic.
--
-- This is the only dimension every other stream can join to: every record-owning
-- module carries owner_id, and nothing else in the Zoho schema carries a foreign
-- key. Sync this stream even if you think you do not need it.
--
-- Single Zoho org. To add another, UNION ALL a second block below pointing at that
-- org's connector with a different zoho_org label. Keep it in staging so the core
-- models never have to know how many orgs there are.

SELECT
    'org_1'                                 AS zoho_org,
    CAST(id AS STRING)                      AS user_id,
    NULLIF(TRIM(CAST(full_name AS STRING)), '')  AS full_name,
    CAST(first_name AS STRING)              AS first_name,
    CAST(last_name AS STRING)               AS last_name,
    LOWER(NULLIF(TRIM(CAST(email AS STRING)), '')) AS email,
    CAST(status AS STRING)                  AS status,
    -- Zoho keeps deactivated users in the module rather than deleting them, so
    -- filtering on this is how you get "reps who could take a deal today".
    LOWER(CAST(status AS STRING)) = 'active' AS is_active,
    CAST(role_name AS STRING)               AS role_name,
    CAST(profile_name AS STRING)            AS profile_name,
    CAST(created_time AS TIMESTAMP)         AS created_time,
    CAST(modified_time AS TIMESTAMP)        AS modified_time
FROM {{raw.zoho_crm.user}}
