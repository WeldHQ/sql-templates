-- analytics.tiktok_shop.shop_performance
-- BI-facing contract over the core model. Dashboards bind here so core can be
-- renamed, re-grained or split without breaking anything downstream.

SELECT * FROM {{core.tiktok_shop.shop_performance}}
