-- Debits equal credits: every company's G/L entries for a posting month sum to zero.
--
-- Business Central only posts balanced transactions, so a failure means entries are
-- missing from the sync (an interrupted incremental run, or a month only partly loaded)
-- or that entries were duplicated. Checked per month rather than per document, because a
-- document number is not guaranteed to be one balanced transaction.

SELECT
    company_id,
    posting_month,
    SUM(amount) AS imbalance
FROM {{ ref('core_business_central__general_ledger') }}
GROUP BY 1, 2
HAVING ABS(SUM(amount)) > 0.01
