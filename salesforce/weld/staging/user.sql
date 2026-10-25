-- staging.salesforce.user
-- Thin wrapper over raw `user`. Casts and renames. Grain: one row per user.
--
-- Salesforce never deletes users, it deactivates them, so the object has no
-- is_deleted column and nothing is filtered. Deactivated reps stay, flagged by
-- is_active, because their opportunities and activities still exist.
--
-- Records can also be owned by a queue rather than a user (common for leads).
-- Queue ids start with 00G and are not in this table, so an owner that does not
-- resolve here is usually a queue.

SELECT
    'org_1'                                        AS salesforce_org,
    CAST(id AS STRING)                             AS user_id,
    NULLIF(TRIM(CAST(name AS STRING)), '')         AS user_name,
    LOWER(NULLIF(TRIM(CAST(email AS STRING)), '')) AS email,
    NULLIF(TRIM(CAST(title AS STRING)), '')        AS title,
    NULLIF(TRIM(CAST(department AS STRING)), '')   AS department,
    CAST(user_role_id AS STRING)                   AS user_role_id,
    CAST(manager_id AS STRING)                     AS manager_id,
    CAST(user_type AS STRING)                      AS user_type,
    CAST(is_active AS BOOL)                        AS is_active
FROM {{raw.salesforce.user}}
