-- stg_harvest__user
-- Thin wrapper over raw `user`. One row per Harvest user.
--
-- Harvest's API returns weekly_capacity in SECONDS (126000 for a 35-hour week).
-- It is converted to hours here.

SELECT
    CAST(id AS STRING)                                  AS user_id,
    TRIM(CONCAT(COALESCE(first_name, ''), ' ', COALESCE(last_name, ''))) AS user_name,
    LOWER(CAST(email AS STRING))                        AS email,
    COALESCE(is_active, FALSE)                          AS is_active,
    COALESCE(is_contractor, FALSE)                      AS is_contractor,
    CAST(weekly_capacity AS FLOAT64) / 3600             AS weekly_capacity_hours,
    CAST(roles AS STRING)                               AS roles_json
FROM {{ source('harvest', 'user') }}
WHERE id IS NOT NULL
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY CAST(id AS STRING)
    ORDER BY CAST(updated_at AS TIMESTAMP) DESC, _weld_synced DESC
) = 1
