-- stg_facebook_ads__ad_roas_insight_actions
-- Thin wrapper over raw `ad_roas_insight_actions`: Meta's `actions` array for
-- each row of the ad level insights report, landed by the connector as one row
-- per action type. Casts, renames, de-duplicates. Values are counts.
-- Grain: ad account x ad x date x action_type.
--
-- value is Meta's figure under the attribution windows the connector requests
-- (7-day click and 1-day view unless the connection is set otherwise). Per-window
-- columns (seven_d_click, one_d_view, ...) are present only on some connections,
-- so they are not read here; add them if yours has them.

SELECT * EXCEPT (row_rank)
FROM (
    SELECT
        CAST(date AS DATE)                                       AS date_day,
        REGEXP_REPLACE(CAST(account_id AS STRING), r'^act_', '') AS account_id,
        CAST(campaign_id AS STRING)                              AS campaign_id,
        CAST(adset_id AS STRING)                                 AS ad_set_id,
        CAST(ad_id AS STRING)                                    AS ad_id,
        CAST(action_type AS STRING)                              AS action_type,
        COALESCE(CAST(value AS FLOAT64), 0)                      AS action_count,
        ROW_NUMBER() OVER (
            PARTITION BY account_id, campaign_id, adset_id, ad_id, date, action_type
            ORDER BY _weld_synced DESC
        ) AS row_rank
    FROM {{ source('facebook_ads', 'ad_roas_insight_actions') }}
)
WHERE row_rank = 1
