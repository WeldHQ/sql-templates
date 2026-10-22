-- analytics.sprout_social.case_resolution
-- BI-facing contract over the core model. Deliberately thin: dashboards bind to
-- this name, so core can be refactored without breaking anything downstream.

SELECT * FROM {{core.sprout_social.case_resolution}}
