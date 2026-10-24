-- stg_auth0__stats_daily
-- Thin wrapper over raw `stats_daily`: Auth0's own daily counters, the numbers on
-- the tenant Dashboard. Casts, renames, keeps one row per day.
--
-- Grain: one row per UTC day. The connector re-reads the last three days on every
-- run, because Auth0 keeps updating the current day.

SELECT * EXCEPT (row_rank)
FROM (
    SELECT
        DATE(CAST(date AS TIMESTAMP))       AS date_day,
        CAST(logins AS INT64)               AS logins,
        CAST(signups AS INT64)              AS signups,
        CAST(leaked_passwords AS INT64)     AS leaked_passwords,
        ROW_NUMBER() OVER (PARTITION BY DATE(CAST(date AS TIMESTAMP)) ORDER BY _weld_synced DESC) AS row_rank
    FROM {{ source('auth0', 'stats_daily') }}
)
WHERE row_rank = 1
