-- analytics.linkedin_pages.follower_growth_daily
-- BI-facing contract over the core model. Deliberately thin: dashboards bind to
-- this name, so core can be refactored without breaking anything downstream.

SELECT * FROM {{core.linkedin_pages.follower_growth_daily}}
