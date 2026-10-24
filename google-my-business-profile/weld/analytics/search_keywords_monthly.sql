-- analytics.google_my_business_profile.search_keywords_monthly
-- BI-facing contract over the core model. Deliberately thin: dashboards bind to
-- this name, so core can be refactored without breaking anything downstream.

SELECT * FROM {{core.google_my_business_profile.search_keywords_monthly}}
