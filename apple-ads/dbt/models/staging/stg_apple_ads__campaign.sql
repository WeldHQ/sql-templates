-- stg_apple_ads__campaign
-- Thin wrapper over raw `campaigns`. Casts, renames, parses the budget objects,
-- keeps the latest row per campaign.
-- Grain: one row per campaign. Latest means last synced; Apple's own
-- modification time breaks a tie between rows from the same sync.

SELECT * EXCEPT (row_rank)
FROM (
    SELECT
        CAST(id AS STRING)                 AS campaign_id,
        CAST(name AS STRING)               AS campaign_name,
        CAST(org_id AS STRING)             AS account_id,
        CAST(adam_id AS STRING)            AS app_id,
        CAST(status AS STRING)             AS status,
        CAST(display_status AS STRING)     AS display_status,
        CAST(serving_status AS STRING)     AS serving_status,
        CAST(deleted AS BOOL)              AS is_deleted,
        CAST(ad_channel_type AS STRING)    AS ad_channel_type,
        CAST(supply_sources AS STRING)     AS supply_sources,
        CAST(payment_model AS STRING)      AS payment_model,
        SAFE_CAST(JSON_VALUE(daily_budget_amount, '$.amount') AS NUMERIC) AS daily_budget,
        SAFE_CAST(JSON_VALUE(budget_amount, '$.amount') AS NUMERIC)       AS total_budget,
        ROW_NUMBER() OVER (
            PARTITION BY id
            ORDER BY _weld_synced DESC, SAFE_CAST(modification_time AS TIMESTAMP) DESC
        ) AS row_rank
    FROM {{ source('apple_ads', 'campaigns') }}
)
WHERE row_rank = 1
