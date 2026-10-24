-- analytics.forex_v2.daily_rates
-- BI-facing contract over the core model. Dashboards and other templates bind here
-- so the core model can be renamed, re-grained or split without breaking anything
-- downstream.

SELECT * FROM {{core.forex_v2.daily_rates}}
