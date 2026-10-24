-- staging.asana.user
-- Thin wrapper over raw `user`. One row per user. The raw table has one row per
-- user per workspace; the QUALIFY keeps one, since names and emails are global.

SELECT
    CAST(gid AS STRING)           AS user_id,
    CAST(name AS STRING)          AS user_name,
    LOWER(CAST(email AS STRING))  AS email
FROM {{raw.asana.user}}
WHERE gid IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY CAST(gid AS STRING) ORDER BY _weld_synced DESC) = 1
