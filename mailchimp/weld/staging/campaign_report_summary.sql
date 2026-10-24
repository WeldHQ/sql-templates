-- staging.mailchimp.campaign_report_summary
-- Thin wrapper over raw `campaign_report_summary`: the headline numbers Mailchimp shows
-- on a campaign's report. Casts. No other logic.
--
-- Grain: campaign_id.
-- `open_rate` and `click_rate` are fractions (0.42, not 42), computed by Mailchimp over
-- successful deliveries. `subscriber_clicks` is the number of unique recipients who
-- clicked. E-commerce figures are in the connected store's currency and only populated
-- when a store is connected to the audience.

SELECT
    CAST(campaign_id AS STRING)             AS campaign_id,
    CAST(opens AS INT64)                    AS opens,
    CAST(unique_opens AS INT64)             AS unique_opens,
    CAST(open_rate AS FLOAT64)              AS open_rate,
    CAST(clicks AS INT64)                   AS clicks,
    CAST(subscriber_clicks AS INT64)        AS unique_clickers,
    CAST(click_rate AS FLOAT64)             AS click_rate,
    CAST(ecommerce_total_orders AS INT64)   AS ecommerce_orders,
    CAST(ecommerce_total_spent AS NUMERIC)  AS ecommerce_total_spent,
    CAST(ecommerce_total_revenue AS NUMERIC) AS ecommerce_revenue
FROM {{raw.mailchimp.campaign_report_summary}}
