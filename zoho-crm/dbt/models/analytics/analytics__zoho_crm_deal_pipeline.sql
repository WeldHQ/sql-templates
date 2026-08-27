-- analytics__zoho_crm_deal_pipeline
-- BI-facing contract over the core model. Dashboards, scheduled reports and
-- reverse-ETL syncs bind HERE, never to core, so core stays free to be renamed,
-- re-grained or split without breaking anything downstream.
--
-- A passthrough is the correct content for this layer. Put BI-specific shaping
-- (renames for a semantic layer, row filters for a workspace) in this file rather
-- than in core.

{{ config(materialized='view') }}

SELECT * FROM {{ ref('core_zoho_crm__deal_pipeline') }}
