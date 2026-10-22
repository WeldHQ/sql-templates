-- core.klarna.payout_reconciliation
-- Every Klarna payout, Klarna's own breakdown of it, and whether the synced
-- transactions add up to that breakdown.
-- Grain: klarna_account x merchant_id x payout (payment_reference).
-- Currency: the payout's own. Never sum across currency_code.
-- Depends on: staging.klarna.payout, staging.klarna.transaction
--
-- WHAT THIS IS FOR. The payout is the number on the bank statement. Finance
-- matches settlement_amount to the bank line, then needs to know what it was
-- made of: sales, minus returns, minus Klarna's fees and the tax on them, minus
-- anything held back. Klarna computes that breakdown itself (the totals_ fields),
-- and this model sets it next to the same figures rebuilt from the transaction
-- ledger, type by type.
--
-- WHY THE TIE-OUT COMPARES ABSOLUTE VALUES. Klarna documents a type for each
-- transaction but no sign convention for amount, and the totals are documented
-- as plain amounts. Comparing ABS(sum per type) with ABS(total) is true whichever
-- convention an account returns, so a difference here always means missing or
-- extra rows, never a sign misunderstanding.
--
-- Only the types with an unambiguous counterpart in the totals are tied out:
-- SALE, RETURN, FEE, FEE_REFUND, REVERSAL, CHARGE, CREDIT, HOLDBACK and RELEASE.
-- TAX, COMMISSION and CORRECTION are shown side by side but not tested, because
-- Klarna splits them across several totals (tax vs tax refund, commission vs
-- commission reversal, fee correction) with no documented type mapping.
--
-- Transactions are aggregated to the payout BEFORE the join, so a payout with
-- 4,000 transactions still contributes one row and no total is multiplied.

WITH txn AS (
    SELECT
        klarna_account,
        merchant_id,
        payment_reference,
        COUNT(*)                                                         AS transactions,
        COUNT(DISTINCT IF(transaction_type = 'SALE', order_id, NULL))    AS orders_sold,
        ABS(SUM(IF(transaction_type = 'SALE',       amount, 0)))        AS txn_sale_amount,
        ABS(SUM(IF(transaction_type = 'RETURN',     amount, 0)))        AS txn_return_amount,
        ABS(SUM(IF(transaction_type = 'FEE',        amount, 0)))        AS txn_fee_amount,
        ABS(SUM(IF(transaction_type = 'FEE_REFUND', amount, 0)))        AS txn_fee_refund_amount,
        ABS(SUM(IF(transaction_type = 'TAX',        amount, 0)))        AS txn_tax_amount,
        ABS(SUM(IF(transaction_type = 'REVERSAL',   amount, 0)))        AS txn_reversal_amount,
        ABS(SUM(IF(transaction_type = 'CHARGE',     amount, 0)))        AS txn_charge_amount,
        ABS(SUM(IF(transaction_type = 'CREDIT',     amount, 0)))        AS txn_credit_amount,
        ABS(SUM(IF(transaction_type = 'HOLDBACK',   amount, 0)))        AS txn_holdback_amount,
        ABS(SUM(IF(transaction_type = 'RELEASE',    amount, 0)))        AS txn_release_amount,
        ABS(SUM(IF(transaction_type = 'COMMISSION', amount, 0)))        AS txn_commission_amount,
        ABS(SUM(IF(transaction_type = 'CORRECTION', amount, 0)))        AS txn_correction_amount,
        -- Net of every type whose direction is documented. Types with no documented
        -- direction are excluded and counted separately, so a non-zero
        -- undirected_transactions tells you net_of_directed_types is incomplete.
        SUM(IF(ledger_direction IS NOT NULL, signed_amount, 0))          AS net_of_directed_types,
        COUNTIF(ledger_direction IS NULL)                                AS undirected_transactions
    FROM {{staging.klarna.transaction}}
    GROUP BY 1, 2, 3
),

joined AS (
    SELECT
        p.*,
        COALESCE(t.transactions, 0)              AS transactions,
        COALESCE(t.orders_sold, 0)               AS orders_sold,
        COALESCE(t.txn_sale_amount, 0)           AS txn_sale_amount,
        COALESCE(t.txn_return_amount, 0)         AS txn_return_amount,
        COALESCE(t.txn_fee_amount, 0)            AS txn_fee_amount,
        COALESCE(t.txn_fee_refund_amount, 0)     AS txn_fee_refund_amount,
        COALESCE(t.txn_tax_amount, 0)            AS txn_tax_amount,
        COALESCE(t.txn_reversal_amount, 0)       AS txn_reversal_amount,
        COALESCE(t.txn_charge_amount, 0)         AS txn_charge_amount,
        COALESCE(t.txn_credit_amount, 0)         AS txn_credit_amount,
        COALESCE(t.txn_holdback_amount, 0)       AS txn_holdback_amount,
        COALESCE(t.txn_release_amount, 0)        AS txn_release_amount,
        COALESCE(t.txn_commission_amount, 0)     AS txn_commission_amount,
        COALESCE(t.txn_correction_amount, 0)     AS txn_correction_amount,
        COALESCE(t.net_of_directed_types, 0)     AS net_of_directed_types,
        COALESCE(t.undirected_transactions, 0)   AS undirected_transactions
    FROM {{staging.klarna.payout}} p
    LEFT JOIN txn t
        ON  t.klarna_account    = p.klarna_account
        AND t.merchant_id       = p.merchant_id
        AND t.payment_reference = p.payment_reference
)

SELECT
    klarna_account,
    merchant_id,
    payment_reference,
    payout_date,
    payout_at,
    currency_code,
    merchant_settlement_type,

    -- What landed in the bank, per Klarna.
    settlement_amount,

    -- Klarna's own breakdown of the payout.
    sale_amount,
    return_amount,
    fee_amount,
    fee_correction_amount,
    fee_refund_amount,
    tax_amount,
    tax_refund_amount,
    commission_amount,
    commission_reversal_amount,
    reversal_amount,
    charge_amount,
    credit_amount,
    holdback_amount,
    release_amount,
    repay_amount,
    deposit_amount,
    opening_debt_balance_amount,
    closing_debt_balance_amount,

    -- Effective fee rate on this payout: fees plus the tax on them, net of refunded
    -- fees, over sales. A ratio of the payout's sums, not an average of
    -- per-transaction rates, so large orders weigh what they cost.
    SAFE_DIVIDE(ABS(fee_amount) + ABS(tax_amount) - ABS(fee_refund_amount), ABS(sale_amount))
        AS effective_fee_rate,

    -- The same breakdown rebuilt from the transaction ledger.
    transactions,
    orders_sold,
    txn_sale_amount,
    txn_return_amount,
    txn_fee_amount,
    txn_fee_refund_amount,
    txn_tax_amount,
    txn_reversal_amount,
    txn_charge_amount,
    txn_credit_amount,
    txn_holdback_amount,
    txn_release_amount,
    txn_commission_amount,
    txn_correction_amount,
    net_of_directed_types,
    undirected_transactions,

    -- Differences for the types that have a one-to-one total. Zero is a tie.
    ROUND(txn_sale_amount       - ABS(sale_amount), 2)       AS sale_difference,
    ROUND(txn_return_amount     - ABS(return_amount), 2)     AS return_difference,
    ROUND(txn_fee_amount        - ABS(fee_amount), 2)        AS fee_difference,
    ROUND(txn_fee_refund_amount - ABS(fee_refund_amount), 2) AS fee_refund_difference,
    ROUND(txn_reversal_amount   - ABS(reversal_amount), 2)   AS reversal_difference,
    ROUND(txn_charge_amount     - ABS(charge_amount), 2)     AS charge_difference,
    ROUND(txn_credit_amount     - ABS(credit_amount), 2)     AS credit_difference,
    ROUND(txn_holdback_amount   - ABS(holdback_amount), 2)   AS holdback_difference,
    ROUND(txn_release_amount    - ABS(release_amount), 2)    AS release_difference,

    -- One flag to filter on. COALESCE because a NULL total (the field missing from
    -- an older payout) would otherwise make the whole comparison NULL, and a
    -- WHERE NOT ties_out would silently skip it.
    COALESCE(
        transactions > 0
        AND ABS(txn_sale_amount       - ABS(COALESCE(sale_amount, 0)))       <= 0.01
        AND ABS(txn_return_amount     - ABS(COALESCE(return_amount, 0)))     <= 0.01
        AND ABS(txn_fee_amount        - ABS(COALESCE(fee_amount, 0)))        <= 0.01
        AND ABS(txn_fee_refund_amount - ABS(COALESCE(fee_refund_amount, 0))) <= 0.01
        AND ABS(txn_reversal_amount   - ABS(COALESCE(reversal_amount, 0)))   <= 0.01
        AND ABS(txn_charge_amount     - ABS(COALESCE(charge_amount, 0)))     <= 0.01
        AND ABS(txn_credit_amount     - ABS(COALESCE(credit_amount, 0)))     <= 0.01
        AND ABS(txn_holdback_amount   - ABS(COALESCE(holdback_amount, 0)))   <= 0.01
        AND ABS(txn_release_amount    - ABS(COALESCE(release_amount, 0)))    <= 0.01,
        FALSE
    ) AS ties_out
FROM joined
