-- stg_calendly__organization_membership
-- Thin wrapper over raw `list_organization_memberships`: the current members of the
-- Calendly organisation, with name and email unpacked from the `user` object.
--
-- Current state only. Someone who left the organisation is gone from this table but
-- can still be a host on old meetings, which is why core builds its host list from
-- both this table and the meetings themselves.
--
-- Single Calendly organisation; see staging.calendly.scheduled_event.

SELECT
    'account_1'                                AS calendly_account,
    CAST(uri AS STRING)                        AS membership_uri,
    JSON_VALUE(user, '$.uri')                  AS user_uri,
    JSON_VALUE(user, '$.name')                 AS user_name,
    LOWER(JSON_VALUE(user, '$.email'))         AS user_email,
    JSON_VALUE(user, '$.timezone')             AS user_timezone,
    CAST(role AS STRING)                       AS role,
    SAFE_CAST(created_at AS TIMESTAMP)         AS created_at
FROM {{ source('calendly', 'list_organization_memberships') }}
WHERE uri IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY uri ORDER BY SAFE_CAST(updated_at AS TIMESTAMP) DESC) = 1
