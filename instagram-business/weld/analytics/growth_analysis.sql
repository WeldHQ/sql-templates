-- analytics.instagram_business.growth_analysis
-- BI-facing contract over the core model. Dashboards bind here so core can
-- change without breaking them. A passthrough on purpose.

SELECT * FROM {{core.instagram_business.growth_analysis}}
