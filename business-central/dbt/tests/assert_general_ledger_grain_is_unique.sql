-- One row per G/L entry. Entry numbers repeat across companies, so the key is
-- (company_id, entry_number); a duplicate means a join fanned out or two copies of an
-- entry survived de-duplication.

SELECT
    company_id,
    entry_number,
    COUNT(*) AS rows_per_key
FROM {{ ref('core_business_central__general_ledger') }}
GROUP BY 1, 2
HAVING COUNT(*) > 1
