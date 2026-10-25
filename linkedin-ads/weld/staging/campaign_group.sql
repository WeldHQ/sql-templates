-- staging.linkedin_ads.campaign_group
-- Thin wrapper over raw `campaign_group`. Casts, renames, keeps the latest row per
-- campaign group.
-- Grain: one row per campaign group.

SELECT
    CAST(id AS STRING)                     AS campaign_group_id,
    CAST(account_id AS STRING)             AS account_id,
    CAST(name AS STRING)                   AS campaign_group_name,
    CAST(status AS STRING)                 AS campaign_group_status,
    CAST(run_schedule_start AS TIMESTAMP)  AS run_schedule_start,
    CAST(run_schedule_end AS TIMESTAMP)    AS run_schedule_end
FROM {{raw.linkedin_ads.campaign_group}}
QUALIFY ROW_NUMBER() OVER (PARTITION BY account_id, id ORDER BY _weld_synced DESC) = 1
