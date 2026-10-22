-- stg_toast__time_entry
-- Thin wrapper over raw `time_entry`. One row per clock-in, latest version,
-- deleted entries removed. Hours are split into regular and overtime by Toast;
-- hourly_wage is the wage on the entry.

SELECT
    CAST(guid AS STRING)                    AS time_entry_id,
    CAST(restaurant_guid AS STRING)         AS restaurant_id,
    CAST(employee_reference_guid AS STRING) AS employee_id,
    CAST(job_reference_guid AS STRING)      AS job_id,
    DATE(CAST(business_date AS TIMESTAMP))  AS business_date,
    CAST(in_date AS TIMESTAMP)              AS clock_in_at,
    CAST(out_date AS TIMESTAMP)             AS clock_out_at,
    COALESCE(CAST(regular_hours AS FLOAT64), 0)  AS regular_hours,
    COALESCE(CAST(overtime_hours AS FLOAT64), 0) AS overtime_hours,
    CAST(hourly_wage AS FLOAT64)            AS hourly_wage,
    COALESCE(CAST(declared_cash_tips AS FLOAT64), 0) AS declared_cash_tips,
    COALESCE(CAST(non_cash_tips AS FLOAT64), 0)      AS non_cash_tips,
    COALESCE(auto_clocked_out, FALSE)       AS was_auto_clocked_out
FROM {{ source('toast', 'time_entry') }}
WHERE guid IS NOT NULL
  AND COALESCE(deleted, FALSE) = FALSE
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY CAST(guid AS STRING)
    ORDER BY CAST(modified_date AS TIMESTAMP) DESC, _weld_synced DESC
) = 1
