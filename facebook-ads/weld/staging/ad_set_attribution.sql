-- staging.facebook_ads.ad_set_attribution
-- The ad set's attribution setting, from raw `ad_set_attribution` (one row per
-- ad set and event type, unpacked from the ad set's attribution spec). Keeps the
-- latest sync per ad set and folds the rows into one readable label.
-- Grain: one row per ad set.
--
-- attribution_setting reads like Ads Manager, e.g. "7-day click, 1-day view".
-- event_type is CLICK_THROUGH, VIEW_THROUGH or ENGAGED_VIDEO_VIEW.

WITH latest AS (
    SELECT
        CAST(adset_id AS STRING)    AS ad_set_id,
        CAST(event_type AS STRING)  AS event_type,
        CAST(window_days AS INT64)  AS window_days,
        _weld_synced,
        MAX(_weld_synced) OVER (PARTITION BY adset_id) AS last_synced
    FROM {{raw.facebook_ads.ad_set_attribution}}
)

SELECT
    ad_set_id,
    STRING_AGG(
        DISTINCT CONCAT(
            CAST(window_days AS STRING), '-day ',
            CASE event_type
                WHEN 'CLICK_THROUGH'      THEN 'click'
                WHEN 'VIEW_THROUGH'       THEN 'view'
                WHEN 'ENGAGED_VIDEO_VIEW' THEN 'engaged view'
                ELSE LOWER(event_type)
            END
        ),
        ', '
    ) AS attribution_setting,
    MAX(IF(event_type = 'CLICK_THROUGH', window_days, NULL)) AS click_window_days,
    MAX(IF(event_type = 'VIEW_THROUGH', window_days, NULL))  AS view_window_days
FROM latest
WHERE _weld_synced = last_synced
GROUP BY ad_set_id
