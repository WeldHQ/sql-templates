-- stg_klarna__payout
-- Thin wrapper over raw `payout`. One row per payout Klarna made to a merchant
-- account: when it landed, in which currency, and Klarna's own breakdown of it.
--
-- MINOR UNITS. Klarna's Settlements API reports every amount as an integer in the
-- currency's minor unit (EUR 12.34 arrives as 1234). Everything is divided by 100
-- here, once, so no core model can forget to. Every currency Klarna settles in has
-- two decimals.
--
-- The totals_ columns are Klarna's own sums for the payout, computed by Klarna and
-- not by this model. totals_settlement_amount is the amount of the payout itself,
-- which makes this table the external figure the transaction ledger is checked
-- against in core.klarna.payout_reconciliation.
--
-- payment_reference is only unique per merchant account, so merchant_id and the
-- klarna_account label travel with it into every join.

SELECT
    'account_1'                                                     AS klarna_account,
    CAST(merchant_id AS STRING)                                     AS merchant_id,
    CAST(payment_reference AS STRING)                               AS payment_reference,
    UPPER(NULLIF(TRIM(CAST(currency_code AS STRING)), ''))          AS currency_code,
    -- NET, GROSS or GROSS_FEE: whether Klarna deducted its fees from this payout
    -- (NET) or invoices them separately (GROSS). It changes what settlement_amount
    -- means, so it is kept on every row.
    UPPER(NULLIF(TRIM(CAST(merchant_settlement_type AS STRING)), '')) AS merchant_settlement_type,
    CAST(payout_date AS TIMESTAMP)                                  AS payout_at,
    DATE(CAST(payout_date AS TIMESTAMP))                            AS payout_date,

    ROUND(CAST(totals_settlement_amount AS NUMERIC) / 100, 2)           AS settlement_amount,
    ROUND(CAST(totals_sale_amount AS NUMERIC) / 100, 2)                 AS sale_amount,
    ROUND(CAST(totals_return_amount AS NUMERIC) / 100, 2)               AS return_amount,
    ROUND(CAST(totals_fee_amount AS NUMERIC) / 100, 2)                  AS fee_amount,
    ROUND(CAST(totals_fee_correction_amount AS NUMERIC) / 100, 2)       AS fee_correction_amount,
    ROUND(CAST(totals_fee_refund_amount AS NUMERIC) / 100, 2)           AS fee_refund_amount,
    ROUND(CAST(totals_tax_amount AS NUMERIC) / 100, 2)                  AS tax_amount,
    ROUND(CAST(totals_tax_refund_amount AS NUMERIC) / 100, 2)           AS tax_refund_amount,
    ROUND(CAST(totals_commission_amount AS NUMERIC) / 100, 2)           AS commission_amount,
    ROUND(CAST(totals_commission_reversal_amount AS NUMERIC) / 100, 2)  AS commission_reversal_amount,
    ROUND(CAST(totals_reversal_amount AS NUMERIC) / 100, 2)             AS reversal_amount,
    ROUND(CAST(totals_charge_amount AS NUMERIC) / 100, 2)               AS charge_amount,
    ROUND(CAST(totals_credit_amount AS NUMERIC) / 100, 2)               AS credit_amount,
    ROUND(CAST(totals_holdback_amount AS NUMERIC) / 100, 2)             AS holdback_amount,
    ROUND(CAST(totals_release_amount AS NUMERIC) / 100, 2)              AS release_amount,
    ROUND(CAST(totals_repay_amount AS NUMERIC) / 100, 2)                AS repay_amount,
    ROUND(CAST(totals_deposit_amount AS NUMERIC) / 100, 2)              AS deposit_amount,
    ROUND(CAST(totals_opening_debt_balance_amount AS NUMERIC) / 100, 2) AS opening_debt_balance_amount,
    ROUND(CAST(totals_closing_debt_balance_amount AS NUMERIC) / 100, 2) AS closing_debt_balance_amount
FROM {{ source('klarna', 'payout') }}
