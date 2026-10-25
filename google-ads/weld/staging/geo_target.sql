-- staging.google_ads.geo_target
-- Thin wrapper over raw `geo_target`, Google's list of geo target constants.
-- Casts, renames, keeps one row per ID.
-- Grain: one row per geo target.

SELECT * EXCEPT (row_rank)
FROM (
    SELECT
        CAST(id AS STRING)             AS geo_target_id,
        CAST(name AS STRING)           AS geo_target_name,
        CAST(canonical_name AS STRING) AS canonical_name,
        CAST(country_code AS STRING)   AS country_code,
        CAST(target_type AS STRING)    AS target_type,
        ROW_NUMBER() OVER (PARTITION BY id ORDER BY _weld_synced DESC) AS row_rank
    FROM {{raw.google_ads.geo_target}}
)
WHERE row_rank = 1
