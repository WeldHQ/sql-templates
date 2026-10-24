-- staging.sprout_social.cases
-- Thin wrapper over raw `cases`, Sprout Social customer care cases. Casts, renames,
-- keeps the latest version of each case.
--
-- Grain: one row per case.
--
-- The connector re-reads cases updated since the previous sync, so a case that
-- changes lands again; only the newest version is kept. Timestamps are UTC.
-- assigned_to arrives as a JSON array of Sprout user URNs.

SELECT * EXCEPT (row_rank)
FROM (
    SELECT
        CAST(case_id AS STRING)               AS case_id,
        CAST(group_id AS STRING)              AS group_id,
        CAST(queue_id AS STRING)              AS queue_id,
        UPPER(CAST(status AS STRING))         AS case_status,
        UPPER(CAST(priority AS STRING))       AS case_priority,
        UPPER(CAST(type AS STRING))           AS case_type,
        CAST(created_time AS TIMESTAMP)       AS created_at,
        CAST(updated_time AS TIMESTAMP)       AS updated_at,
        CAST(last_closed_time AS TIMESTAMP)   AS last_closed_at,
        CAST(created_by AS STRING)            AS created_by,
        CAST(assigned_by AS STRING)           AS assigned_by,
        CAST(assigned_to AS STRING)           AS assigned_to_json,
        ROW_NUMBER() OVER (PARTITION BY case_id ORDER BY updated_time DESC, _weld_synced DESC) AS row_rank
    FROM {{raw.sprout_social.cases}}
)
WHERE row_rank = 1
