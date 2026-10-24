-- analytics.daisycon.publisher_performance
-- BI-facing contract over the core model. Deliberately thin: dashboards bind to
-- this name, so core can be refactored without breaking anything downstream.

SELECT * FROM {{core.daisycon.publisher_performance}}
