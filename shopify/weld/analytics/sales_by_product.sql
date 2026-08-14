-- analytics.shopify.sales_by_product
-- BI-facing contract over the core model. See analytics/sales_over_time.sql for
-- why this layer exists even when it is a passthrough.

SELECT * FROM {{core.shopify.sales_by_product}}
