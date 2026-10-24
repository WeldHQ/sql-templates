-- analytics.toast_analytics.menu_item_performance
-- BI-facing contract over the core model. See shopify/weld/analytics/sales_over_time.sql
-- for why this layer exists even when it is a passthrough.

SELECT * FROM {{core.toast_analytics.menu_item_performance}}
