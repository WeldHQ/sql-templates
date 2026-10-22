-- staging.hibob.time_off_request
-- Thin wrapper over raw `time_off`. One row per time off request, from HiBob's
-- "who's out" endpoint, which returns approved and pending requests.
--
-- Dates arrive as text (YYYY-MM-DD) and are cast here. `type` is how the request
-- was booked: days, hours, a portion of a day and so on.

SELECT
    CAST(request_id AS INT64)                   AS request_id,
    CAST(employee_id AS STRING)                 AS employee_id,
    CAST(employee_display_name AS STRING)       AS employee_display_name,
    CAST(policy_type AS STRING)                 AS policy_type,
    CAST(policy_type_display_name AS STRING)    AS policy_type_name,
    LOWER(CAST(type AS STRING))                 AS request_type,
    LOWER(CAST(status AS STRING))               AS status,
    SAFE_CAST(LEFT(CAST(start_date AS STRING), 10) AS DATE) AS start_date,
    CAST(start_portion AS STRING)               AS start_portion,
    SAFE_CAST(LEFT(CAST(end_date AS STRING), 10) AS DATE)   AS end_date,
    CAST(end_portion AS STRING)                 AS end_portion
FROM {{raw.hibob.time_off}}
WHERE request_id IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY CAST(request_id AS INT64) ORDER BY _weld_synced DESC) = 1
