-- staging.google_play.subscriptions_by_country
-- Thin wrapper over raw `financial_stats_subscriptions_country`: Play Console's
-- daily subscription counts per subscription product, base plan, offer and buyer
-- country. Casts, renames, keeps the newest read of each row.
--
-- Grain: one row per day x package x product x base plan x offer x country.
--
-- new_subscriptions and canceled_subscriptions are counts for the day.
-- active_subscriptions is how many were active on that day, a level: add it up
-- across products, plans, offers and countries on one day, never across days.

SELECT
    CAST(date AS DATE)                          AS date_day,
    CAST(package_name AS STRING)                AS package_name,
    CAST(product_id AS STRING)                  AS product_id,
    CAST(base_plan_id AS STRING)                AS base_plan_id,
    CAST(offer_id AS STRING)                    AS offer_id,
    UPPER(CAST(country AS STRING))              AS country,
    CAST(new_subscriptions AS INT64)            AS new_subscriptions,
    CAST(canceled_subscriptions AS INT64)       AS canceled_subscriptions,
    CAST(active_subscriptions AS INT64)         AS active_subscriptions
FROM {{raw.google_play.financial_stats_subscriptions_country}}
WHERE TRUE
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY date, package_name, product_id, base_plan_id, offer_id, country
    ORDER BY file_last_modified DESC, _weld_synced DESC
) = 1
