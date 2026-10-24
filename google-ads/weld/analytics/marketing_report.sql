-- analytics.google_ads.marketing_report
-- BI-facing contract over the core model. Dashboards bind here so core can
-- change without breaking them. A passthrough on purpose.

SELECT * FROM {{core.google_ads.marketing_report}}
