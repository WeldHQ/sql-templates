-- Revenue and commission in campaign_performance are plain sums. They only mean
-- something if every conversion on the campaign is in the same currency.
--
-- Lists campaigns where that is not true. If this returns rows, report those
-- campaigns from conversions_by_day, which keeps currency in the grain.

SELECT grin_account, campaign_id, campaign_name, revenue_currencies
FROM {{ ref('core_grin__campaign_performance') }}
WHERE revenue_currencies > 1
