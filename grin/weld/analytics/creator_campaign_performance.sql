-- analytics.grin.creator_campaign_performance
-- BI-facing contract over the core model. Dashboards bind here so core can be
-- renamed or re-grained without breaking them. A passthrough on purpose.

SELECT * FROM {{core.grin.creator_campaign_performance}}
