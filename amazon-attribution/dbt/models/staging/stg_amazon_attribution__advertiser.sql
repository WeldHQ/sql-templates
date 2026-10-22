-- stg_amazon_attribution__advertiser
-- Thin wrapper over raw `advertiser`, the Amazon Attribution advertisers under each
-- profile. Casts, renames, keeps the latest row per advertiser and profile.
-- Grain: one row per profile x advertiser.

SELECT * EXCEPT (row_rank)
FROM (
    SELECT
        CAST(profile_id AS STRING)      AS profile_id,
        CAST(advertiser_id AS STRING)   AS advertiser_id,
        CAST(advertiser_name AS STRING) AS advertiser_name,
        ROW_NUMBER() OVER (PARTITION BY profile_id, advertiser_id ORDER BY _weld_synced DESC) AS row_rank
    FROM {{ source('amazon_attribution', 'advertiser') }}
)
WHERE row_rank = 1
