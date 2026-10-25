-- analytics.facebook_ads.conversions_by_action_type_daily
-- BI-facing contract over the core model. Deliberately thin: dashboards bind to
-- this name, so core can be refactored without breaking anything downstream.

SELECT * FROM {{core.facebook_ads.conversions_by_action_type_daily}}
