-- analytics.zoho_crm.rep_activity
-- BI-facing contract over the core model. See analytics/deal_pipeline.sql for why
-- this layer exists even when it is a passthrough.
--
-- Reminder for whoever binds a dashboard to this: activity here is per rep only.
-- There is no deal or account key on Zoho's call, task and event streams in this
-- connector, so do not label a tile "activity per opportunity".

SELECT * FROM {{core.zoho_crm.rep_activity}}
