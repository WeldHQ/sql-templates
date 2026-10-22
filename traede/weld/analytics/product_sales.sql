-- analytics.traede.product_sales
-- BI-facing contract over the core model. See analytics/invoiced_sales_over_time.sql
-- for why this layer exists even when it is a passthrough.

SELECT * FROM {{core.traede.product_sales}}
