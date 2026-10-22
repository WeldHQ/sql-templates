-- core.auth0.logins_by_application
-- Login and signup activity per application and connection, from the tenant log.
-- Answers "which app is failing logins" and "which connection do people sign up
-- with", which Auth0's Dashboard only shows tenant-wide.
--
-- Grain: one row per UTC day x client (application) x connection.
-- Depends on: staging.auth0.logs
--
-- Events without a client or connection (some failures happen before Auth0 has
-- resolved either) keep NULL in that column rather than being dropped, so the
-- counts sum back to tenant_activity_daily.

SELECT
    event_date                                                      AS date_day,
    client_id,
    ANY_VALUE(client_name)                                          AS client_name,
    connection_name,
    ANY_VALUE(strategy)                                             AS strategy,

    COUNTIF(event_category = 'login_success')                       AS logins,
    COUNTIF(event_category = 'login_failure')                       AS failed_logins,
    COUNTIF(login_failure_reason = 'wrong_password')                AS failed_logins_wrong_password,
    COUNTIF(login_failure_reason = 'unknown_user')                  AS failed_logins_unknown_user,
    COUNTIF(event_category = 'signup_success')                      AS signups,
    COUNTIF(event_category = 'signup_failure')                      AS failed_signups,
    COUNTIF(event_category = 'login_success' AND is_mobile)         AS mobile_logins,

    -- Distinct per row only: a user who logs in to two apps counts in both, so do
    -- not sum this column across clients. Use tenant_activity_daily for a total.
    COUNT(DISTINCT IF(event_category = 'login_success', user_id, NULL)) AS users_logging_in,

    ROUND(SAFE_DIVIDE(
        COUNTIF(event_category = 'login_success'),
        COUNTIF(event_category IN ('login_success', 'login_failure'))
    ), 4)                                                           AS login_success_rate
FROM {{staging.auth0.logs}}
WHERE event_category IN ('login_success', 'login_failure', 'signup_success', 'signup_failure')
GROUP BY event_date, client_id, connection_name
