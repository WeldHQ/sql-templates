-- analytics.hubspot.deals_by_deal_stage
-- BI-facing contract over the core model. Dashboards bind here so core can
-- change without breaking them. A passthrough on purpose.

SELECT * FROM {{core.hubspot.deals_by_deal_stage}}
