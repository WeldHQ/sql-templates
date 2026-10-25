-- core.facebook_ads.conversions_by_action_type_daily
-- Every conversion event Meta reports, per ad and day: purchases, leads, add to
-- carts, registrations, app installs, custom conversions. Ads Manager's
-- "Results" columns, one row per event.
--
-- Grain: date_day x account_id x ad_id x action_type. Currency: the ad account's.
-- Depends on: staging.facebook_ads.ad_roas_insight_actions,
-- .ad_roas_insight_action_values, core.facebook_ads.ad_performance_daily
--
-- action_count comes from the actions array, action_value from the
-- action_values array (NULL for events Meta reports no value for).
--
-- Do not sum action_count across action types: Meta reports the same purchase
-- under several types (purchase, omni_purchase, offsite_conversion.fb_pixel_purchase,
-- onsite_web_purchase ...). Pick one type per event. spend is not repeated here;
-- join to ad_performance_daily on date_day, account_id and ad_id for cost per
-- action, after filtering to one action type.

WITH counts AS (
    SELECT
        date_day, account_id, ad_id, action_type,
        SUM(action_count)          AS action_count
    FROM {{staging.facebook_ads.ad_roas_insight_actions}}
    GROUP BY 1, 2, 3, 4
),

action_values AS (
    SELECT
        date_day, account_id, ad_id, action_type,
        SUM(action_value)          AS action_value
    FROM {{staging.facebook_ads.ad_roas_insight_action_values}}
    GROUP BY 1, 2, 3, 4
),

ads AS (
    -- One row per ad and day already; only the labels are needed.
    SELECT date_day, account_id, ad_id, account_name, currency,
           campaign_id, campaign_name, ad_set_id, ad_set_name, ad_name
    FROM {{core.facebook_ads.ad_performance_daily}}
)

SELECT
    COALESCE(c.date_day, v.date_day)       AS date_day,
    COALESCE(c.account_id, v.account_id)   AS account_id,
    ads.account_name,
    ads.currency,
    ads.campaign_id,
    ads.campaign_name,
    ads.ad_set_id,
    ads.ad_set_name,
    COALESCE(c.ad_id, v.ad_id)             AS ad_id,
    ads.ad_name,
    COALESCE(c.action_type, v.action_type) AS action_type,
    COALESCE(c.action_count, 0)            AS action_count,
    v.action_value
FROM counts c
FULL OUTER JOIN action_values v
  ON v.date_day = c.date_day AND v.account_id = c.account_id
 AND v.ad_id = c.ad_id AND v.action_type = c.action_type
LEFT JOIN ads
  ON ads.date_day = COALESCE(c.date_day, v.date_day)
 AND ads.account_id = COALESCE(c.account_id, v.account_id)
 AND ads.ad_id = COALESCE(c.ad_id, v.ad_id)
