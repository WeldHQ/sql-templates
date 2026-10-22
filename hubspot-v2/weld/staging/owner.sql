-- staging.hubspot_v2.owner
-- Thin wrapper over raw `owner`. Grain: one row per owner.
--
-- Owners are the people records can be assigned to. Archived owners (deactivated
-- users) are KEPT and flagged: their deals and activities still exist, and dropping
-- them would turn every name on that history into NULL.

SELECT
    'portal_1'                                         AS hubspot_portal,
    CAST(owner_id AS STRING)                           AS owner_id,
    CAST(user_id AS STRING)                            AS user_id,
    LOWER(NULLIF(TRIM(email), ''))                     AS owner_email,
    NULLIF(TRIM(CONCAT(COALESCE(first_name, ''), ' ', COALESCE(last_name, ''))), '') AS owner_name,
    NOT COALESCE(archived, FALSE)                      AS owner_is_active
FROM {{raw.hubspot_v2.owner}}
