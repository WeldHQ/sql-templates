-- stg_auth0__user_identities
-- Thin wrapper over raw `user_identities`: the identity providers linked to each
-- user. Casts, renames, de-duplicates.
--
-- Grain: one row per user x identity position (index). Index 0 is the identity the
-- user was created with; linked accounts follow at 1, 2, ...

SELECT * EXCEPT (row_rank)
FROM (
    SELECT
        CAST(user_id AS STRING)             AS user_id,
        CAST(`index` AS INT64)              AS identity_index,
        CAST(connection AS STRING)          AS connection_name,
        CAST(provider AS STRING)            AS provider,
        COALESCE(CAST(is_social AS BOOL), FALSE) AS is_social,
        ROW_NUMBER() OVER (
            PARTITION BY user_id, `index` ORDER BY _weld_synced DESC
        ) AS row_rank
    FROM {{ source('auth0', 'user_identities') }}
)
WHERE row_rank = 1
