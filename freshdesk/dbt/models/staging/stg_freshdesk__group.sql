-- stg_freshdesk__group
-- Thin wrapper over raw `group`. One row per Freshdesk group.

SELECT
    'account_1'                                  AS freshdesk_account,
    CAST(id AS STRING)                           AS group_id,
    NULLIF(TRIM(CAST(name AS STRING)), '')       AS group_name
FROM {{ source('freshdesk', 'group') }}
WHERE id IS NOT NULL
