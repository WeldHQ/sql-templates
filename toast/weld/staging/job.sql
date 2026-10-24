-- staging.toast.job
-- Thin wrapper over raw `job`. One row per job (role) per restaurant.

SELECT
    CAST(guid AS STRING)                    AS job_id,
    CAST(restaurant_guid AS STRING)         AS restaurant_id,
    CAST(title AS STRING)                   AS job_title,
    CAST(code AS STRING)                    AS job_code,
    COALESCE(tipped, FALSE)                 AS is_tipped,
    COALESCE(exclude_from_reporting, FALSE) AS exclude_from_reporting
FROM {{raw.toast.job}}
WHERE guid IS NOT NULL
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY CAST(guid AS STRING), CAST(restaurant_guid AS STRING)
    ORDER BY _weld_synced DESC
) = 1
