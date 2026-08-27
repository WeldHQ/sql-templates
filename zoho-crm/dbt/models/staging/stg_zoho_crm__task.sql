-- stg_zoho_crm__task
-- Thin wrapper over raw `task`. Casts, renames, derives is_completed.
--
-- NO PARENT LINK. Zoho's Tasks module has What_Id / Who_Id (the deal, account,
-- contact or lead the task hangs off), but the connector does not sync them. The
-- only foreign key on this stream is owner_id, so a task can be counted per rep
-- and per day and nothing else. Do not join it to a deal - there is no key to
-- join on.

SELECT
    'org_1'                                 AS zoho_org,
    CAST(id AS STRING)                      AS task_id,
    NULLIF(TRIM(CAST(subject AS STRING)), '')  AS subject,
    NULLIF(TRIM(CAST(status AS STRING)), '')   AS status,
    NULLIF(TRIM(CAST(priority AS STRING)), '') AS priority,
    CAST(due_date AS DATE)                  AS due_date,
    -- Zoho's default Task statuses are Not Started, Deferred, In Progress,
    -- Completed and Waiting for input. Matched on a pattern rather than equality
    -- so a renamed or translated status does not silently read as incomplete.
    LOWER(CAST(status AS STRING)) LIKE '%complet%' AS is_completed,
    CAST(owner_id AS STRING)                AS owner_id,
    CAST(created_time AS TIMESTAMP)         AS created_time,
    CAST(modified_time AS TIMESTAMP)        AS modified_time
FROM {{ source('zoho_crm', 'task') }}
