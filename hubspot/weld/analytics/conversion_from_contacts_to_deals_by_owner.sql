-- analytics.hubspot.conversion_from_contacts_to_deals_by_owner
-- BI-facing contract over the core model. Dashboards bind here so core can
-- change without breaking them. A passthrough on purpose.

SELECT * FROM {{core.hubspot.conversion_from_contacts_to_deals_by_owner}}
