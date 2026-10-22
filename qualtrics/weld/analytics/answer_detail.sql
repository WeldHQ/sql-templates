-- analytics.qualtrics.answer_detail
-- BI-facing contract over the core model. Dashboards, scheduled reports and
-- reverse-ETL syncs bind here, never to core, so core stays free to be renamed,
-- re-grained or split without breaking anything downstream.

SELECT * FROM {{core.qualtrics.answer_detail}}
