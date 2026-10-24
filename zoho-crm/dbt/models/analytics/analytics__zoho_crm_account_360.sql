-- analytics__zoho_crm_account_360
-- BI-facing contract over the core model. See analytics/deal_pipeline.sql for why
-- this layer exists even when it is a passthrough.
--
-- This is the natural source for a reverse-ETL sync back into Zoho: writing
-- open_pipeline_amount or is_stale_with_open_pipeline onto the Account record puts
-- the warehouse's view in front of the reps who need it.

{{ config(materialized='view') }}

SELECT * FROM {{ ref('core_zoho_crm__account_360') }}
