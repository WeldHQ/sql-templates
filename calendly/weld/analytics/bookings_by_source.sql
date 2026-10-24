-- analytics.calendly.bookings_by_source
-- BI-facing contract over the core model. Dashboards bind here so core can be
-- renamed or re-grained without breaking them. A passthrough on purpose.

SELECT * FROM {{core.calendly.bookings_by_source}}
