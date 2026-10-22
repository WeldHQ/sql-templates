-- analytics.business_central.profit_and_loss_by_month
-- BI-facing contract over the core model. Dashboards bind here so the core model can
-- be renamed, re-grained or split without breaking anything downstream.

SELECT * FROM {{core.business_central.profit_and_loss_by_month}}
