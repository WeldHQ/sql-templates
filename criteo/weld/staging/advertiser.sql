-- staging.criteo.advertiser
-- Thin wrapper over raw `advertiser`. Casts, renames, keeps the latest row per advertiser.
-- Grain: one row per advertiser. An advertiser is the Criteo equivalent of an ad account.

SELECT * EXCEPT (row_rank)
FROM (
    SELECT
        CAST(id AS STRING)                         AS account_id,
        CAST(attributes_advertiser_name AS STRING) AS account_name,
        ROW_NUMBER() OVER (PARTITION BY id ORDER BY _weld_synced DESC) AS row_rank
    FROM {{raw.criteo.advertiser}}
)
WHERE row_rank = 1
