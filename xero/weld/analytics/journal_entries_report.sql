-- analytics.xero.journal_entries_report
-- BI-facing contract over the core model. Dashboards bind here so core can
-- change without breaking them. A passthrough on purpose.

SELECT * FROM {{core.xero.journal_entries_report}}
