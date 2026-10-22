-- analytics.klaviyo.monthly_campaign_status_breakdown_by_list
-- BI-facing contract over the core model. Dashboards bind here so core can
-- change without breaking them. A passthrough on purpose.

SELECT * FROM {{core.klaviyo.monthly_campaign_status_breakdown_by_list}}
