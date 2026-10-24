-- staging.criteo.adset
-- Thin wrapper over raw `adset`. Casts, renames, keeps the latest row per ad set.
-- Grain: one row per ad set.

SELECT * EXCEPT (row_rank)
FROM (
    SELECT
        CAST(id AS STRING)                                    AS adset_id,
        CAST(attributes_name AS STRING)                       AS adset_name,
        CAST(attributes_campaign_id AS STRING)                AS campaign_id,
        CAST(attributes_advertiser_id AS STRING)              AS account_id,
        CAST(attributes_objective AS STRING)                  AS objective,
        CAST(attributes_schedule_activation_status AS STRING) AS activation_status,
        CAST(attributes_schedule_delivery_status AS STRING)   AS delivery_status,
        ROW_NUMBER() OVER (PARTITION BY id ORDER BY _weld_synced DESC) AS row_rank
    FROM {{raw.criteo.adset}}
)
WHERE row_rank = 1
