-- analytics.microsoft_ads.ad_group_report
-- BI-facing contract over the core model. Dashboards bind here so core can
-- change without breaking them. A passthrough on purpose.

SELECT * FROM {{core.microsoft_ads.ad_group_report}}
