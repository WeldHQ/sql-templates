-- analytics__salesforce_pipeline_flow_daily
-- BI-facing contract over the core model. Dashboards, scheduled reports and
-- reverse-ETL syncs bind here, never to core, so core stays free to be renamed,
-- re-grained or split without breaking anything downstream.

{{ config(materialized='view') }}

SELECT * FROM {{ ref('core_salesforce__pipeline_flow_daily') }}
