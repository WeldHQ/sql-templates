-- stg_pinterest_ads__campaign
-- Thin wrapper over raw `campaign`. Casts, renames, converts micros, keeps the
-- latest row per campaign (the stream is incremental on update time and can hold
-- several versions of one campaign).
-- Grain: one row per campaign.

SELECT
    CAST(id AS STRING)                         AS campaign_id,
    CAST(ad_account_id AS STRING)              AS account_id,
    CAST(name AS STRING)                       AS campaign_name,
    CAST(status AS STRING)                     AS campaign_status,
    CAST(summary_status AS STRING)             AS campaign_summary_status,
    CAST(objective_type AS STRING)             AS objective_type,
    CAST(daily_spend_cap AS FLOAT64) / 1000000     AS daily_spend_cap,
    CAST(lifetime_spend_cap AS FLOAT64) / 1000000  AS lifetime_spend_cap,
    CAST(start_time AS TIMESTAMP)              AS start_time,
    CAST(end_time AS TIMESTAMP)                AS end_time
FROM {{ source('pinterest_ads', 'campaign') }}
QUALIFY ROW_NUMBER() OVER (PARTITION BY ad_account_id, id ORDER BY _weld_synced DESC) = 1
