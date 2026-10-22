-- analytics.gong.scorecard_scores_by_rep
-- BI-facing contract over the core model. Dashboards bind here so core can be
-- renamed or re-grained without breaking them. A passthrough on purpose.

SELECT * FROM {{core.gong.scorecard_scores_by_rep}}
