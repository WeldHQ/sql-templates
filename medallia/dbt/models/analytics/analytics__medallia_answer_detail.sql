-- analytics__medallia_answer_detail
-- BI-facing contract over the core model. Dashboards, scheduled reports and
-- reverse-ETL syncs bind here, never to core, so core stays free to be renamed,
-- re-grained or split without breaking anything downstream.

{{ config(materialized='view') }}

SELECT * FROM {{ ref('core_medallia__answer_detail') }}
