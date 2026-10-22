-- analytics.google_search_console.query_page_monthly
-- BI-facing contract over the core model. Deliberately thin: dashboards bind to
-- this name, so core can be refactored without breaking anything downstream.

SELECT * FROM {{core.google_search_console.query_page_monthly}}
