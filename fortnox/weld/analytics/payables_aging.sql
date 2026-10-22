-- analytics.fortnox.payables_aging
-- BI-facing contract over the core model. Dashboards bind here so the core model can
-- be renamed, re-grained or split without breaking anything downstream.

SELECT * FROM {{core.fortnox.payables_aging}}
