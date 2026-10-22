-- staging.notion.user
-- Thin wrapper over raw `user`. One row per person or bot in the workspace.

SELECT
    CAST(id AS STRING)                   AS user_id,
    LOWER(CAST(type AS STRING))          AS user_type,
    CAST(name AS STRING)                 AS user_name,
    LOWER(CAST(person_email AS STRING))  AS email
FROM {{raw.notion.user}}
WHERE id IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY CAST(id AS STRING) ORDER BY _weld_synced DESC) = 1
