-- stg_auth0__logs
-- Thin wrapper over raw `logs`, Auth0's tenant log. Casts, renames, de-duplicates,
-- and maps Auth0's event type codes to a small set of categories. No other logic.
--
-- Grain: one row per log event (log_id).
--
-- Auth0 keeps tenant logs for 1 to 30 days depending on plan, and the connector's
-- first run starts at the oldest event the tenant still has. History before that
-- does not exist anywhere, so the earliest days in this table are the start of your
-- record, not a dip in activity.
--
-- The category mapping follows Auth0's log event type codes. Codes not listed fall
-- into 'other' and keep their raw value in event_type, so a code Auth0 adds later
-- is visible rather than silently dropped.

SELECT * EXCEPT (row_rank)
FROM (
    SELECT
        CAST(log_id AS STRING)                          AS log_id,
        CAST(date AS TIMESTAMP)                         AS event_at,
        DATE(CAST(date AS TIMESTAMP))                   AS event_date,
        CAST(type AS STRING)                            AS event_type,
        CAST(description AS STRING)                     AS description,

        CASE
            WHEN type IN ('s', 'sens', 'scoa')                          THEN 'login_success'
            WHEN type IN ('f', 'fp', 'fu', 'fc', 'fco', 'fcoa', 'fens') THEN 'login_failure'
            WHEN type = 'ssa'                                           THEN 'silent_auth_success'
            WHEN type = 'fsa'                                           THEN 'silent_auth_failure'
            WHEN type = 'ss'                                            THEN 'signup_success'
            WHEN type = 'fs'                                            THEN 'signup_failure'
            -- Token exchanges made on behalf of a user. seccft (client credentials)
            -- is machine-to-machine and has no user, so it is kept out on purpose.
            WHEN type IN ('seacft', 'sertft', 'sepft', 'sede', 'seoobft',
                          'seotpft', 'sercft')                          THEN 'user_token_exchange_success'
            WHEN type = 'seccft'                                        THEN 'machine_token_exchange_success'
            WHEN type IN ('limit_wc', 'limit_mu')                       THEN 'blocked_by_attack_protection'
            WHEN type IN ('slo', 'flo')                                 THEN 'logout'
            ELSE 'other'
        END                                             AS event_category,

        -- Why a login failed, for the failure categories only.
        CASE
            WHEN type = 'fp' THEN 'wrong_password'
            WHEN type = 'fu' THEN 'unknown_user'
            WHEN type IN ('f', 'fc', 'fco', 'fcoa', 'fens') THEN 'other'
        END                                             AS login_failure_reason,

        NULLIF(CAST(user_id AS STRING), '')             AS user_id,
        CAST(user_name AS STRING)                       AS user_name,
        CAST(client_id AS STRING)                       AS client_id,
        CAST(client_name AS STRING)                     AS client_name,
        CAST(connection_id AS STRING)                   AS connection_id,
        CAST(connection AS STRING)                      AS connection_name,
        CAST(strategy AS STRING)                        AS strategy,
        CAST(strategy_type AS STRING)                   AS strategy_type,
        CAST(organization_id AS STRING)                 AS organization_id,
        CAST(is_mobile AS BOOL)                         AS is_mobile,
        CAST(ip AS STRING)                              AS ip,
        UPPER(CAST(location_info_country_code AS STRING)) AS country_code,

        ROW_NUMBER() OVER (PARTITION BY log_id ORDER BY _weld_synced DESC) AS row_rank
    FROM {{ source('auth0', 'logs') }}
)
WHERE row_rank = 1
