-- core_adyen__settlement_batches
-- Adyen's settlement batches, itemised: what was settled, what came back out as
-- refunds and chargebacks, what Adyen and the card schemes withheld, and what was
-- paid to your bank account. Recreates the batch view of the Settlement details
-- report in the Customer Area.
--
-- Grain: merchant account x batch number x net (settlement) currency. Entries with
-- no batch number, if any, are kept in one row with a NULL batch_number rather than
-- dropped, so totals still match the report.
-- Depends on: staging.adyen.settlement_detail
--
-- SIGNS. Credits to the batch are positive, debits negative, so every column below
-- is a plain sum and
--     settled_net + refunds + chargebacks + adyen_fees + invoice_deductions
--       + reserve_movements + balance_transfers + other_entries
-- is the batch's net movement before payout. `payout` is shown as a positive
-- number (the amount sent to your bank). `unreconciled_amount` is the net movement
-- minus the payout and should be zero for a batch that has been paid out. A batch
-- that has not been paid out yet, or whose balance was carried into a later batch,
-- has no payout and a non-zero net movement.
--
-- FEES. `settled_gross` is the settled amount before transaction fees, in the net
-- currency: net credit plus the fees withheld from it. Transaction fees are already
-- inside settled_net and refunds, so they are reported separately for analysis and
-- are not part of the sum above.

SELECT
    s.merchant_account,
    s.batch_number,
    s.net_currency,
    ANY_VALUE(s.company_account)                                                  AS company_account,
    MIN(s.created_date_local)                                                     AS first_entry_date,
    MAX(s.created_date_local)                                                     AS last_entry_date,
    MAX(CASE WHEN s.entry_category = 'payout' THEN s.created_date_local END)      AS payout_date,
    ANY_VALUE(s.time_zone)                                                        AS time_zone,

    COUNTIF(s.entry_category = 'settled')                                         AS settled_entries,
    COUNTIF(s.entry_category = 'refund')                                          AS refund_entries,
    COUNTIF(s.entry_category = 'chargeback')                                      AS chargeback_entries,

    SUM(CASE WHEN s.entry_category = 'settled' THEN s.net_amount_nc + s.transaction_fees_nc ELSE 0 END) AS settled_gross,
    SUM(CASE WHEN s.entry_category = 'settled'           THEN s.net_amount_nc ELSE 0 END) AS settled_net,
    SUM(CASE WHEN s.entry_category = 'refund'            THEN s.net_amount_nc ELSE 0 END) AS refunds,
    SUM(CASE WHEN s.entry_category = 'chargeback'        THEN s.net_amount_nc ELSE 0 END) AS chargebacks,
    SUM(CASE WHEN s.entry_category = 'adyen_fee'         THEN s.net_amount_nc ELSE 0 END) AS adyen_fees,
    SUM(CASE WHEN s.entry_category = 'invoice_deduction' THEN s.net_amount_nc ELSE 0 END) AS invoice_deductions,
    SUM(CASE WHEN s.entry_category = 'reserve'           THEN s.net_amount_nc ELSE 0 END) AS reserve_movements,
    SUM(CASE WHEN s.entry_category = 'balance_transfer'  THEN s.net_amount_nc ELSE 0 END) AS balance_transfers,
    SUM(CASE WHEN s.entry_category IN ('other', 'unclassified') THEN s.net_amount_nc ELSE 0 END) AS other_entries,

    -- Fees withheld from settled, refunded and charged back entries. Positive is a
    -- cost. Already deducted inside the columns above.
    SUM(CASE WHEN s.entry_category IN ('settled', 'refund', 'chargeback') THEN s.transaction_fees_nc ELSE 0 END) AS transaction_fees,
    SUM(CASE WHEN s.entry_category IN ('settled', 'refund', 'chargeback') THEN COALESCE(s.interchange_nc, 0) ELSE 0 END) AS interchange,
    SUM(CASE WHEN s.entry_category IN ('settled', 'refund', 'chargeback') THEN COALESCE(s.scheme_fees_nc, 0) ELSE 0 END) AS scheme_fees,
    SUM(CASE WHEN s.entry_category IN ('settled', 'refund', 'chargeback') THEN COALESCE(s.markup_nc, 0) ELSE 0 END) AS markup,
    SUM(CASE WHEN s.entry_category IN ('settled', 'refund', 'chargeback') THEN COALESCE(s.commission_nc, 0) ELSE 0 END) AS commission,

    SUM(CASE WHEN s.entry_category <> 'payout' THEN s.net_amount_nc ELSE 0 END)  AS net_movement,
    -SUM(CASE WHEN s.entry_category = 'payout' THEN s.net_amount_nc ELSE 0 END)  AS payout,
    COUNTIF(s.entry_category = 'payout') > 0                                      AS has_payout,

    -- Zero when the batch's entries add up to what was paid out. Only meaningful
    -- when has_payout is TRUE.
    SUM(s.net_amount_nc)                                                          AS unreconciled_amount
FROM {{ ref('stg_adyen__settlement_detail') }} s
GROUP BY s.merchant_account, s.batch_number, s.net_currency
