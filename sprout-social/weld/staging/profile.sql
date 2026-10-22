-- staging.sprout_social.profile
-- Thin wrapper over raw `profile`, the social profiles connected to Sprout Social.
-- Casts, renames, keeps the latest row per profile.
-- Grain: one row per Sprout profile (customer_profile_id).

SELECT * EXCEPT (row_rank)
FROM (
    SELECT
        CAST(customer_profile_id AS STRING) AS customer_profile_id,
        CAST(customer_id AS STRING)         AS customer_id,
        CAST(name AS STRING)                AS profile_name,
        CAST(native_name AS STRING)         AS native_name,
        CAST(native_id AS STRING)           AS native_id,
        UPPER(CAST(network_type AS STRING)) AS network_type,
        ROW_NUMBER() OVER (PARTITION BY customer_profile_id ORDER BY _weld_synced DESC) AS row_rank
    FROM {{raw.sprout_social.profile}}
)
WHERE row_rank = 1
