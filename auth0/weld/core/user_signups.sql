-- core.auth0.user_signups
-- New users per day by how they signed up, and how many went on to verify their
-- email and come back. The signup side of Auth0's Users page, as a time series.
--
-- Grain: one row per UTC signup day x connection x provider.
-- Depends on: staging.auth0.users, staging.auth0.user_identities
--
-- Built from the users table, not the log, so it covers your whole user base back
-- to the first user rather than only the log retention window. Each user is placed
-- on the connection of their primary identity (index 0), the one they were created
-- with; later account linking does not move them.

SELECT
    u.created_date                                      AS signup_date,
    i.connection_name,
    i.provider,
    ANY_VALUE(i.is_social)                              AS is_social,

    COUNT(*)                                            AS new_users,
    COUNTIF(u.is_email_verified)                        AS email_verified_users,
    -- logins_count includes the login that created the account, so > 1 means the
    -- user came back at least once.
    COUNTIF(u.logins_count > 1)                         AS returned_users,
    COUNTIF(u.last_login_at IS NULL)                    AS never_logged_in_users,
    COUNTIF(u.is_blocked)                               AS blocked_users,

    ROUND(SAFE_DIVIDE(COUNTIF(u.is_email_verified), COUNT(*)), 4) AS email_verified_rate,
    ROUND(SAFE_DIVIDE(COUNTIF(u.logins_count > 1), COUNT(*)), 4)  AS returned_rate
FROM {{staging.auth0.users}} u
LEFT JOIN {{staging.auth0.user_identities}} i
  ON  i.user_id = u.user_id
  AND i.identity_index = 0
WHERE u.created_date IS NOT NULL
GROUP BY u.created_date, i.connection_name, i.provider
