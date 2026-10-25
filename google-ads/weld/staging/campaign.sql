-- staging.google_ads.campaign
-- Thin wrapper over raw `campaign`. Casts, renames, keeps the latest row per campaign.
-- Grain: one row per account x campaign.

SELECT * EXCEPT (row_rank)
FROM (
    SELECT
        CAST(account_id AS STRING)                    AS account_id,
        CAST(id AS STRING)                            AS campaign_id,
        CAST(name AS STRING)                          AS campaign_name,
        CAST(advertising_channel_type AS STRING)      AS channel_type,
        CAST(advertising_channel_sub_type AS STRING)  AS channel_sub_type,
        CAST(status AS STRING)                        AS campaign_status,
        CAST(final_url_suffix AS STRING)              AS final_url_suffix,
        ROW_NUMBER() OVER (PARTITION BY account_id, id ORDER BY _weld_synced DESC) AS row_rank
    FROM {{raw.google_ads.campaign}}
)
WHERE row_rank = 1
