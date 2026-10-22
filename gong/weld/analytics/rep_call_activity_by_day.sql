-- analytics.gong.rep_call_activity_by_day
-- BI-facing contract over the core model. Dashboards bind here so core can be
-- renamed or re-grained without breaking them. A passthrough on purpose.

SELECT * FROM {{core.gong.rep_call_activity_by_day}}
