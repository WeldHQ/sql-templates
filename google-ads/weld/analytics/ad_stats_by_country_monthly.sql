-- analytics.google_ads.ad_stats_by_country_monthly
-- BI-facing contract over the core model. Dashboards bind here so core can
-- change without breaking them. A passthrough on purpose.

SELECT * FROM {{core.google_ads.ad_stats_by_country_monthly}}
