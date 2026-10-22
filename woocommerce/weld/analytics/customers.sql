-- analytics.woocommerce.customers
-- BI-facing contract over the core model. Dashboards bind here so core can be
-- renamed or re-grained without breaking anything downstream.

SELECT * FROM {{core.woocommerce.customers}}
