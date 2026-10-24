-- staging.harvest.time_entry
-- Thin wrapper over raw `time_entry`. One row per time entry, latest version.
--
-- The stream is incremental on Harvest's updated_since filter, so an edited entry
-- arrives again and the QUALIFY keeps the newest. An entry deleted in Harvest is
-- NOT removed from the raw table: the API does not report deletions. See the
-- README for how to spot them.
--
-- `rounded_hours` follows the time rounding setting in your Harvest account and is
-- what Harvest uses on invoices and in its reports; it equals `hours` when rounding
-- is off. `cost_rate` arrives as text and is cast here.

SELECT
    CAST(id AS STRING)                          AS time_entry_id,
    DATE(CAST(spent_date AS TIMESTAMP))         AS spent_date,
    CAST(user_id AS STRING)                     AS user_id,
    CAST(user_name AS STRING)                   AS user_name,
    CAST(client_id AS STRING)                   AS client_id,
    CAST(client_name AS STRING)                 AS client_name,
    UPPER(CAST(client_currency AS STRING))      AS client_currency,
    CAST(project_id AS STRING)                  AS project_id,
    CAST(project_name AS STRING)                AS project_name,
    CAST(project_code AS STRING)                AS project_code,
    CAST(task_id AS STRING)                     AS task_id,
    CAST(task_name AS STRING)                   AS task_name,
    CAST(hours AS FLOAT64)                      AS hours,
    CAST(COALESCE(rounded_hours, hours) AS FLOAT64) AS rounded_hours,
    COALESCE(billable, FALSE)                   AS is_billable,
    COALESCE(budgeted, FALSE)                   AS is_budgeted,
    COALESCE(is_billed, FALSE)                  AS is_billed,
    COALESCE(is_running, FALSE)                 AS is_running,
    CAST(billable_rate AS FLOAT64)              AS billable_rate,
    SAFE_CAST(CAST(cost_rate AS STRING) AS FLOAT64) AS cost_rate,
    CAST(created_at AS TIMESTAMP)               AS created_at,
    CAST(updated_at AS TIMESTAMP)               AS updated_at
FROM {{raw.harvest.time_entry}}
WHERE id IS NOT NULL
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY CAST(id AS STRING)
    ORDER BY CAST(updated_at AS TIMESTAMP) DESC, _weld_synced DESC
) = 1
