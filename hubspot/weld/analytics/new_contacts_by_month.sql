-- analytics.hubspot.new_contacts_by_month
-- BI-facing contract over the core model. Dashboards bind here so core can
-- change without breaking them. A passthrough on purpose.

SELECT * FROM {{core.hubspot.new_contacts_by_month}}
