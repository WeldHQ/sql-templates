-- analytics.google_my_business_profile.reviews_monthly
-- BI-facing contract over the core model. Deliberately thin: dashboards bind to
-- this name, so core can be refactored without breaking anything downstream.

SELECT * FROM {{core.google_my_business_profile.reviews_monthly}}
