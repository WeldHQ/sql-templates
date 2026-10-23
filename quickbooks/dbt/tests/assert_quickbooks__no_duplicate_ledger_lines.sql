-- One row per journal line. A duplicate here means the transaction header was not
-- unique in staging and the join multiplied its lines, which would inflate every
-- balance downstream.

SELECT
    quickbooks_company,
    transaction_id,
    transaction_number,
    line_position,
    COUNT(*) AS n
FROM {{ ref('core_quickbooks__general_ledger') }}
GROUP BY 1, 2, 3, 4
HAVING COUNT(*) > 1
