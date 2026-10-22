-- analytics.facebook_ads.marketing_report
-- BI-facing contract over the core model. Dashboards bind here so core can
-- change without breaking them. A passthrough on purpose.

SELECT * FROM {{core.facebook_ads.marketing_report}}
