-- analytics.hubspot.closed_won_deals_amount_by_owner
-- BI-facing contract over the core model. Dashboards bind here so core can
-- change without breaking them. A passthrough on purpose.

SELECT * FROM {{core.hubspot.closed_won_deals_amount_by_owner}}
