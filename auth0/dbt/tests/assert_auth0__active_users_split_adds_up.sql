-- New plus returning plus unmatched active users equals monthly active users.
-- If this fails, a user's created_date is in a later month than their activity,
-- which points at a users row that was re-created or a clock problem upstream.

SELECT *
FROM {{ ref('core_auth0__monthly_active_users') }}
WHERE monthly_active_users
      != new_active_users + returning_active_users + active_users_not_in_users_table
