-- analytics.facebook_ads.conversion_insights
-- BI-facing contract over the core model. Dashboards bind here so core can
-- change without breaking them. A passthrough on purpose.

SELECT * FROM {{core.facebook_ads.conversion_insights}}
