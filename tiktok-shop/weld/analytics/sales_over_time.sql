-- analytics.tiktok_shop.sales_over_time
-- BI-facing contract over the core model. Dashboards bind here so core can be
-- renamed, re-grained or split without breaking anything downstream.

SELECT * FROM {{core.tiktok_shop.sales_over_time}}
