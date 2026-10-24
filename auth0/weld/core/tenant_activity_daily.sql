-- core.auth0.tenant_activity_daily
-- The Auth0 Dashboard, by day: logins, signups and leaked-password detections as
-- Auth0 counts them, next to the same activity rebuilt from the tenant log, with
-- failures broken down by reason and daily active users.
--
-- Grain: one row per UTC day.
-- Depends on: staging.auth0.stats_daily, staging.auth0.logs
--
-- TWO SOURCES, ON PURPOSE. `auth0_logins` and `auth0_signups` are Auth0's own
-- counters (GET /stats/daily) and go back as far as Auth0 reports them. Everything
-- prefixed `log_` is counted from the tenant log, which only exists from the day the
-- connector first ran minus your plan's retention. On days with both, log_logins and
-- auth0_logins should be close; a persistent gap usually means a login type Auth0
-- counts that is not mapped to 'login_success' in staging.auth0.logs.

WITH log_daily AS (
    SELECT
        event_date                                                          AS date_day,
        COUNTIF(event_category = 'login_success')                           AS log_logins,
        COUNTIF(event_category = 'login_failure')                           AS log_failed_logins,
        COUNTIF(login_failure_reason = 'wrong_password')                    AS log_failed_logins_wrong_password,
        COUNTIF(login_failure_reason = 'unknown_user')                      AS log_failed_logins_unknown_user,
        COUNTIF(login_failure_reason = 'other')                             AS log_failed_logins_other,
        COUNTIF(event_category = 'signup_success')                          AS log_signups,
        COUNTIF(event_category = 'signup_failure')                          AS log_failed_signups,
        COUNTIF(event_category = 'silent_auth_success')                     AS log_silent_auths,
        COUNTIF(event_category = 'blocked_by_attack_protection')            AS log_attack_protection_blocks,
        -- A user counts as active on a day when they authenticated in any way:
        -- an interactive login, a silent re-authentication or a token exchange.
        COUNT(DISTINCT IF(
            event_category IN ('login_success', 'silent_auth_success', 'user_token_exchange_success'),
            user_id, NULL))                                                 AS daily_active_users,
        COUNT(DISTINCT IF(event_category = 'login_success', user_id, NULL)) AS users_logging_in
    FROM {{staging.auth0.logs}}
    GROUP BY 1
)

SELECT
    COALESCE(s.date_day, l.date_day)        AS date_day,

    s.logins                                AS auth0_logins,
    s.signups                               AS auth0_signups,
    s.leaked_passwords                      AS auth0_leaked_passwords,

    l.log_logins,
    l.log_failed_logins,
    l.log_failed_logins_wrong_password,
    l.log_failed_logins_unknown_user,
    l.log_failed_logins_other,
    l.log_signups,
    l.log_failed_signups,
    l.log_silent_auths,
    l.log_attack_protection_blocks,
    l.daily_active_users,
    l.users_logging_in,

    -- Share of interactive login attempts that succeeded. A drop here with flat
    -- traffic is the usual first sign of a broken login page or a credential
    -- stuffing attempt; the unknown_user column tells the two apart.
    ROUND(SAFE_DIVIDE(l.log_logins, l.log_logins + l.log_failed_logins), 4) AS login_success_rate,

    -- FALSE on days before the tenant log was first read: the log_ columns are NULL
    -- there because the data does not exist, not because activity was zero.
    l.date_day IS NOT NULL                  AS has_log_coverage
FROM {{staging.auth0.stats_daily}} s
FULL OUTER JOIN log_daily l
  ON l.date_day = s.date_day
