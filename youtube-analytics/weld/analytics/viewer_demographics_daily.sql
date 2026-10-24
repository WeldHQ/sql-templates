-- analytics.youtube_analytics.viewer_demographics_daily
-- BI-facing contract over the core model. Deliberately thin: dashboards bind to
-- this name, so core can be refactored without breaking anything downstream.

SELECT * FROM {{core.youtube_analytics.viewer_demographics_daily}}
