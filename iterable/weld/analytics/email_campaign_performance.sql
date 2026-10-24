-- analytics.iterable.email_campaign_performance
-- BI-facing contract over the core model. Dashboards bind to this name so core can
-- change without breaking them; add BI-specific shaping here rather than in core.

SELECT * FROM {{core.iterable.email_campaign_performance}}
