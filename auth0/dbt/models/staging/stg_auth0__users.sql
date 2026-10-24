-- stg_auth0__users
-- Thin wrapper over raw `users`. Casts, renames, keeps the latest row per user.
-- Grain: one row per user (user_id).
--
-- Auth0 never returns a deleted user, so a user deleted in Auth0 stays in this
-- table with the state it last had. Personal fields (email, names, IP) are left out
-- on purpose; add them back if your reporting needs them.

SELECT * EXCEPT (row_rank)
FROM (
    SELECT
        CAST(user_id AS STRING)                     AS user_id,
        CAST(created_at AS TIMESTAMP)               AS created_at,
        DATE(CAST(created_at AS TIMESTAMP))         AS created_date,
        CAST(updated_at AS TIMESTAMP)               AS updated_at,
        CAST(last_login AS TIMESTAMP)               AS last_login_at,
        CAST(last_password_reset AS TIMESTAMP)      AS last_password_reset_at,
        CAST(logins_count AS INT64)                 AS logins_count,
        COALESCE(CAST(email_verified AS BOOL), FALSE) AS is_email_verified,
        COALESCE(CAST(blocked AS BOOL), FALSE)      AS is_blocked,
        CAST(locale AS STRING)                      AS locale,
        ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY _weld_synced DESC) AS row_rank
    FROM {{ source('auth0', 'users') }}
)
WHERE row_rank = 1
