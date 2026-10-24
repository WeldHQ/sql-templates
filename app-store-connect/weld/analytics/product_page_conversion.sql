-- analytics.app_store_connect.product_page_conversion
-- BI-facing contract over the core model. See the README for why this layer exists
-- even when it is a passthrough.

SELECT * FROM {{core.app_store_connect.product_page_conversion}}
