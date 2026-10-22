-- analytics.traede.invoiced_sales_over_time
-- BI-facing contract over the core model. Bind dashboards here, not to core, so
-- core can be renamed or re-grained without breaking anything downstream.

SELECT * FROM {{core.traede.invoiced_sales_over_time}}
