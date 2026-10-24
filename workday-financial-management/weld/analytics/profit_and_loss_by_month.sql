-- analytics.workday_financial_management.profit_and_loss_by_month
-- BI-facing contract over the core model. Dashboards bind here so core can be
-- renamed, re-grained or split without breaking anything downstream.

SELECT * FROM {{core.workday_financial_management.profit_and_loss_by_month}}
