-- analytics.esmiley.food_waste_by_area_month
-- BI-facing contract over the core model. See shopify/weld/analytics/sales_over_time.sql
-- for why this layer exists even when it is a passthrough.

SELECT * FROM {{core.esmiley.food_waste_by_area_month}}
