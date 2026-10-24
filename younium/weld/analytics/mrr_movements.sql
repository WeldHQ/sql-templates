-- analytics.younium.mrr_movements
-- BI-facing contract over the core model. Dashboards bind to this name so core can
-- change without breaking them; it is a passthrough on purpose.

SELECT * FROM {{core.younium.mrr_movements}}
