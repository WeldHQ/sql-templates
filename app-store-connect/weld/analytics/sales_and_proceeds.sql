-- analytics.app_store_connect.sales_and_proceeds
-- BI-facing contract over the core model. See the README for why this layer exists
-- even when it is a passthrough.

SELECT * FROM {{core.app_store_connect.sales_and_proceeds}}
