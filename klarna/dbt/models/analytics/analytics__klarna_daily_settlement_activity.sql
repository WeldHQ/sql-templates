-- analytics__klarna_daily_settlement_activity
-- BI-facing contract over the core model. See analytics/payout_reconciliation.sql
-- for why this layer exists even when it is a passthrough.

{{ config(materialized='view') }}

SELECT * FROM {{ ref('core_klarna__daily_settlement_activity') }}
