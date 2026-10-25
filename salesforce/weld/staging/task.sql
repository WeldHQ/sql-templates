-- staging.salesforce.task
-- Thin wrapper over raw `task`. Casts, renames, drops deleted records.
-- Grain: one row per task.
--
-- Tasks cover to-dos, logged calls and logged emails; task_subtype says which
-- (Task, Call, Email, ListEmail, Cadence, LinkedIn). Archived tasks (older than
-- Salesforce's archive window) are kept: they are real past activity.
--
-- activity_date is the task's Date field: the due date of a to-do and the day of
-- a logged call or email.

SELECT
    'org_1'                                        AS salesforce_org,
    CAST(id AS STRING)                             AS task_id,
    CAST(owner_id AS STRING)                       AS owner_id,
    CAST(what_id AS STRING)                        AS what_id,
    CAST(who_id AS STRING)                         AS who_id,
    CAST(account_id AS STRING)                     AS account_id,
    NULLIF(TRIM(CAST(subject AS STRING)), '')      AS subject,
    NULLIF(TRIM(CAST(status AS STRING)), '')       AS task_status,
    NULLIF(TRIM(CAST(task_subtype AS STRING)), '') AS task_subtype,
    NULLIF(TRIM(CAST(type AS STRING)), '')         AS task_type,
    CAST(is_closed AS BOOL)                        AS is_closed,
    CAST(call_duration_in_seconds AS INT64)        AS call_duration_seconds,
    DATE(CAST(activity_date AS TIMESTAMP))         AS activity_date,
    CAST(created_date AS TIMESTAMP)                AS created_at
FROM {{raw.salesforce.task}}
WHERE NOT COALESCE(is_deleted, FALSE)
