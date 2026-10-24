-- analytics.instagram_business.media_insights_deep_dive
-- BI-facing contract over the core model. Dashboards bind here so core can
-- change without breaking them. A passthrough on purpose.

SELECT * FROM {{core.instagram_business.media_insights_deep_dive}}
