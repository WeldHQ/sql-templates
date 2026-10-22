-- stg_zendesk__group
-- Thin wrapper over raw `group`. One row per Zendesk group. Deleted groups are
-- kept and flagged, because old tickets still point at them.

SELECT
    'account_1'                                  AS zendesk_account,
    CAST(id AS STRING)                           AS group_id,
    NULLIF(TRIM(CAST(name AS STRING)), '')       AS group_name,
    COALESCE(CAST(deleted AS BOOL), FALSE)       AS is_deleted
FROM {{ source('zendesk', 'group') }}
WHERE id IS NOT NULL
