-- The purchases in ad_performance_daily must equal the omni_purchase rows of the
-- action type breakdown (or the purchase rows where omni_purchase is absent).
-- A mismatch means the two models pick purchases differently.
-- Returns zero rows when they agree.

WITH breakdown AS (
    SELECT
        date_day, account_id, ad_id,
        COALESCE(SUM(IF(action_type = 'omni_purchase', action_count, NULL)),
                 SUM(IF(action_type = 'purchase', action_count, NULL)), 0) AS purchases
    FROM {{ ref('core_facebook_ads__conversions_by_action_type_daily') }}
    GROUP BY 1, 2, 3
)

SELECT a.date_day, a.account_id, a.ad_id, a.conversions, b.purchases
FROM {{ ref('core_facebook_ads__ad_performance_daily') }} a
LEFT JOIN breakdown b USING (date_day, account_id, ad_id)
WHERE ABS(a.conversions - COALESCE(b.purchases, 0)) > 0.001
