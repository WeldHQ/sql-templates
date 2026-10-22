-- Every transaction's debits equal its credits.
--
-- Double entry guarantees this inside QuickBooks, so a failure means lines went
-- missing or were duplicated on the way to the warehouse: usually a transaction
-- edited after it was synced (the incremental sync does not re-read older dates),
-- or a header and its lines that no longer agree on the document number. A full
-- resync of the journal_report stream fixes both.
--
-- One cent of tolerance for rounding.

SELECT
    quickbooks_company,
    transaction_id,
    transaction_number,
    SUM(debit)     AS total_debit,
    SUM(credit)    AS total_credit,
    SUM(net_debit) AS difference
FROM {{ ref('core_quickbooks__general_ledger') }}
GROUP BY 1, 2, 3
HAVING ABS(SUM(net_debit)) > 0.01
