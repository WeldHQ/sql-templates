-- analytics.gong.rep_interaction_stats_by_week
-- BI-facing contract over the core model. Dashboards bind here so core can be
-- renamed or re-grained without breaking them. A passthrough on purpose.

SELECT * FROM {{core.gong.rep_interaction_stats_by_week}}
