-- analytics.mixpanel_source.sessions
-- BI-facing contract over the core model. Dashboards bind to this name so core can
-- change without breaking them; add BI-specific shaping here rather than in core.

SELECT * FROM {{core.mixpanel_source.sessions}}
