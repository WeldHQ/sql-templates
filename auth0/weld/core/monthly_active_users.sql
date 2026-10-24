-- core.auth0.monthly_active_users
-- Monthly active users and how many of them were new that month.
--
-- Grain: one row per calendar month (UTC).
-- Depends on: staging.auth0.logs, staging.auth0.users
--
-- Active means the user authenticated at least once in the month: an interactive
-- login, a silent re-authentication, or a token exchange made for them (refresh
-- token, authorization code, password grant, device code, MFA). Machine-to-machine
-- tokens have no user and are not counted. This follows the spirit of how Auth0
-- describes active users for billing, but Auth0's own billing count is computed on
-- its side and is the one that applies to your invoice; reconcile a closed month
-- against Tenant Settings > Usage before using this for anything contractual.
--
-- A month is only complete when the tenant log covers all of it. The first synced
-- month usually is not, because Auth0 keeps 1 to 30 days of logs depending on plan.
-- `is_complete_month` is FALSE for that month and for the current one.

WITH active AS (
    SELECT
        DATE_TRUNC(event_date, MONTH)   AS month_start,
        user_id
    FROM {{staging.auth0.logs}}
    WHERE user_id IS NOT NULL
      AND event_category IN ('login_success', 'silent_auth_success', 'user_token_exchange_success')
    GROUP BY 1, 2
),

coverage AS (
    SELECT MIN(event_date) AS first_log_date
    FROM {{staging.auth0.logs}}
)

SELECT
    a.month_start,
    COUNT(*)                                                        AS monthly_active_users,
    -- Users created in the same month they were active.
    COUNTIF(DATE_TRUNC(u.created_date, MONTH) = a.month_start)      AS new_active_users,
    COUNTIF(DATE_TRUNC(u.created_date, MONTH) < a.month_start)      AS returning_active_users,
    -- Active in the log but missing from `users`: usually deleted in Auth0 since,
    -- or created before a partial users sync. Kept visible rather than dropped.
    COUNTIF(u.user_id IS NULL)                                      AS active_users_not_in_users_table,
    -- Complete when the log starts on or before the 1st and the month has ended.
    (
        c.first_log_date <= a.month_start
        AND a.month_start < DATE_TRUNC(CURRENT_DATE(), MONTH)
    )                                                               AS is_complete_month
FROM active a
LEFT JOIN {{staging.auth0.users}} u
  ON u.user_id = a.user_id
CROSS JOIN coverage c
GROUP BY a.month_start, c.first_log_date
