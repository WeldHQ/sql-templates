-- stg_monday__user
-- Thin wrapper over raw `user`. One row per monday user.
--
-- The raw id is numeric while items and activity logs carry user ids as text, so
-- it is cast to an integer string here to make the joins line up.

SELECT
    CAST(CAST(id AS INT64) AS STRING)  AS user_id,
    CAST(name AS STRING)               AS user_name,
    LOWER(CAST(email AS STRING))       AS email,
    CAST(title AS STRING)              AS title,
    COALESCE(enabled, FALSE)           AS is_enabled,
    COALESCE(is_guest, FALSE)          AS is_guest,
    COALESCE(is_admin, FALSE)          AS is_admin,
    CAST(created_at AS TIMESTAMP)      AS created_at,
    CAST(last_activity AS TIMESTAMP)   AS last_activity_at
FROM {{ source('monday', 'user') }}
WHERE id IS NOT NULL
