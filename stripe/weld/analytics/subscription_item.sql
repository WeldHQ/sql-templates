-- analytics.stripe.subscription_item
-- BI-facing contract over the core model. Dashboards bind here so core can
-- change without breaking them. A passthrough on purpose.

SELECT * FROM {{core.stripe.subscription_item}}
