-- analytics.facebook_pages.page_performance_daily
-- BI-facing contract over the core model. Deliberately thin: dashboards bind to
-- this name, so core can be refactored without breaking anything downstream.

SELECT * FROM {{core.facebook_pages.page_performance_daily}}
