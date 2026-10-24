-- stg_grin__contact
-- Thin wrapper over raw `contact`: creators and other contacts in Grin. Only
-- the identifying fields reports need; email, phone and address are left in raw.
--
-- `total_reach` is Grin's sum of the creator's followers across connected
-- networks.
--
-- Single Grin account; see staging.grin.campaign.

SELECT
    'account_1'                                                AS grin_account,
    CAST(id AS STRING)                                         AS contact_id,
    NULLIF(TRIM(CONCAT(COALESCE(first_name, ''), ' ', COALESCE(last_name, ''))), '')
                                                               AS contact_name,
    NULLIF(CAST(record_type AS STRING), '')                    AS record_type,
    NULLIF(CAST(stage_id AS STRING), '')                       AS stage_id,
    CAST(total_reach AS INT64)                                 AS total_reach,
    COALESCE(CAST(is_archived AS BOOL), FALSE)                 AS is_archived,
    CAST(created_at AS TIMESTAMP)                              AS created_at
FROM {{ source('grin', 'contact') }}
WHERE id IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY id ORDER BY updated_at DESC, _weld_synced DESC) = 1
