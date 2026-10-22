-- core_app_store_connect__usage_and_stability
-- Sessions, time in app and crashes per app version: App Analytics' Usage and
-- Crashes views side by side, so a release that crashes more per session shows up
-- the day it ships.
--
-- Grain: one row per day x app x app version x device.
-- Depends on: staging.app_store_connect.sessions, staging.app_store_connect.crashes
--
-- Rates are computed from summed counts in the same row. unique_devices is not
-- carried: Apple counts it per row of its own file and it cannot be added up.
-- Both inputs cover opted-in users only, so crashes per session compares like with
-- like.

WITH sessions AS (
    SELECT
        date_day,
        app_apple_id,
        ANY_VALUE(app_name)         AS app_name,
        app_version,
        device,
        SUM(sessions)               AS sessions,
        SUM(total_session_seconds)  AS total_session_seconds
    FROM {{ ref('stg_app_store_connect__sessions') }}
    GROUP BY date_day, app_apple_id, app_version, device
),

crashes AS (
    SELECT
        date_day,
        app_apple_id,
        ANY_VALUE(app_name)         AS app_name,
        app_version,
        device,
        SUM(crashes)                AS crashes
    FROM {{ ref('stg_app_store_connect__crashes') }}
    GROUP BY date_day, app_apple_id, app_version, device
)

SELECT
    COALESCE(s.date_day, c.date_day)            AS date_day,
    COALESCE(s.app_apple_id, c.app_apple_id)    AS app_apple_id,
    COALESCE(s.app_name, c.app_name)            AS app_name,
    COALESCE(s.app_version, c.app_version)      AS app_version,
    COALESCE(s.device, c.device)                AS device,

    COALESCE(s.sessions, 0)                     AS sessions,
    COALESCE(s.total_session_seconds, 0)        AS total_session_seconds,
    COALESCE(c.crashes, 0)                      AS crashes,

    ROUND(SAFE_DIVIDE(s.total_session_seconds, NULLIF(s.sessions, 0)) / 60, 2) AS avg_session_minutes,
    ROUND(SAFE_DIVIDE(c.crashes, NULLIF(s.sessions, 0)) * 1000, 2)             AS crashes_per_1000_sessions
FROM sessions s
FULL OUTER JOIN crashes c
  ON  c.date_day     = s.date_day
  AND c.app_apple_id = s.app_apple_id
  AND c.app_version  = s.app_version
  AND c.device       = s.device
