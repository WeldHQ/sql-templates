-- core.google_play.subscriptions_daily
-- New, canceled and active subscriptions per subscription product and buyer
-- country, by day: the subscription counts behind Play Console's Subscriptions
-- overview, with base plans and offers added together.
--
-- Grain: one row per day x package x product x country.
-- Depends on: staging.google_play.subscriptions_by_country
--
-- ACTIVE IS A LEVEL. active_subscriptions is the count on that day. For a week or
-- a month take the last day, not the sum. new_ and canceled_ are daily flows and
-- do sum over a period.
--
-- A product and country with no row on a day had nothing reported that day; if a
-- dashboard needs a value for every day, carry the last active_subscriptions
-- forward rather than reading the gap as zero.
--
-- Revenue for these subscriptions is in earnings_monthly, joined on package and
-- product: Play's product_id here is the sku_id there.

SELECT
    date_day,
    package_name,
    product_id,
    country,
    SUM(new_subscriptions)                                  AS new_subscriptions,
    SUM(canceled_subscriptions)                             AS canceled_subscriptions,
    SUM(new_subscriptions) - SUM(canceled_subscriptions)    AS net_new_subscriptions,
    SUM(active_subscriptions)                               AS active_subscriptions
FROM {{staging.google_play.subscriptions_by_country}}
GROUP BY date_day, package_name, product_id, country
