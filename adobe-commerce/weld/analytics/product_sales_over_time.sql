-- analytics.adobe_commerce.product_sales_over_time
-- BI-facing contract over the core model. Dashboards bind here so core can be
-- renamed or re-grained without breaking anything downstream.

SELECT * FROM {{core.adobe_commerce.product_sales_over_time}}
