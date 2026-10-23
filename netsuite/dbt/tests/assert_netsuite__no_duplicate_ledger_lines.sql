-- One row per accounting line. A duplicate means a join in
-- core_netsuite__general_ledger multiplied lines, most likely two account rows
-- with the same id, and every balance downstream would be inflated.

SELECT
    netsuite_account,
    transaction_id,
    transaction_line_id,
    accounting_book_id,
    COUNT(*) AS n
FROM {{ ref('core_netsuite__general_ledger') }}
GROUP BY 1, 2, 3, 4
HAVING COUNT(*) > 1
