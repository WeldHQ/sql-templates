-- One row per day, package, product and country in subscriptions_daily.
-- active_subscriptions is a level; a duplicate row would double it on that day
-- and every chart built on the last day of a period would overstate the base.

SELECT
    date_day,
    package_name,
    product_id,
    country,
    COUNT(*) AS row_count
FROM {{ ref('core_google_play__subscriptions_daily') }}
GROUP BY 1, 2, 3, 4
HAVING COUNT(*) > 1
