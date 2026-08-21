-- analytics__amazon_seller_settlement_ledger
-- BI-facing contract over the core model. Deliberately thin.
--
-- The point is not transformation, it is indirection: dashboards, scheduled reports
-- and reverse-ETL syncs bind to this name, so core can be refactored - renamed
-- columns, changed grain, split into pieces - without breaking anything downstream.
-- Add the shaping your BI tool wants here rather than in core.

-- Account-level charges are KEPT. It is tempting to filter them out so every row has
-- a SKU, but storage, advertising and the subscription fee are real money and
-- dropping them here is how a company reports a fee load 10 points lower than its
-- bank statement. Filter on is_account_level in the dashboard instead, where the
-- choice is visible.

{{ config(materialized='view') }}
SELECT *
FROM {{ ref('core_amazon_seller__settlement_ledger') }}
