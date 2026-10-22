-- analytics.klaviyo.monthly_user_engagement_per_campaign
-- BI-facing contract over the core model. Dashboards bind here so core can
-- change without breaking them. A passthrough on purpose.

SELECT * FROM {{core.klaviyo.monthly_user_engagement_per_campaign}}
