-- analytics.adyen.fees_by_payment_method
-- BI-facing contract over the core model. Dashboards bind here so the core model
-- can be renamed, re-grained or split without breaking anything downstream.

SELECT * FROM {{core.adyen.fees_by_payment_method}}
