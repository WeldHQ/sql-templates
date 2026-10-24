-- stg_zendesk__user
-- Thin wrapper over raw `user`. One row per Zendesk user: end users, agents and
-- admins alike, told apart by `role`. Core joins it to name the assignee.

SELECT
    'account_1'                                      AS zendesk_account,
    CAST(id AS STRING)                               AS user_id,
    NULLIF(TRIM(CAST(name AS STRING)), '')           AS user_name,
    LOWER(NULLIF(TRIM(CAST(email AS STRING)), ''))   AS email,
    LOWER(CAST(role AS STRING))                      AS role,
    CAST(active AS BOOL)                             AS is_active,
    CAST(suspended AS BOOL)                          AS is_suspended
FROM {{ source('zendesk', 'user') }}
WHERE id IS NOT NULL
