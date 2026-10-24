-- Every transaction's debits equal its credits, per accounting book and
-- subsidiary, in base currency.
--
-- NetSuite enforces this when it posts, so a failure means lines were lost or
-- doubled on the way: a line removed from a transaction after it was synced (line
-- deletions are not logged and stay in raw), or accounting lines whose
-- transaction line is missing so subsidiary_id came out NULL. A full resync of
-- transactionaccountingline and transactionline fixes the first; check that both
-- streams are selected for the second.
--
-- One cent of tolerance for rounding.

SELECT
    netsuite_account,
    accounting_book_id,
    subsidiary_id,
    transaction_id,
    SUM(net_debit) AS difference
FROM {{ ref('core_netsuite__general_ledger') }}
GROUP BY 1, 2, 3, 4
HAVING ABS(SUM(net_debit)) > 0.01
