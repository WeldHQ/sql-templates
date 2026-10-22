-- analytics.facebook_pages.post_performance
-- BI-facing contract over the core model. Deliberately thin: dashboards bind to
-- this name, so core can be refactored without breaking anything downstream.

SELECT * FROM {{core.facebook_pages.post_performance}}
