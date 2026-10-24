-- analytics.twilio.message_errors_daily
-- BI-facing contract over the core model. Dashboards bind to this name so core can
-- change without breaking them; add BI-specific shaping here rather than in core.

SELECT * FROM {{core.twilio.message_errors_daily}}
