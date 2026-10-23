-- Clicks, transactions and commission can never be negative. A negative value
-- usually means a field was mapped to the wrong column.

SELECT *
FROM {{ ref('core_daisycon__publisher_performance') }}
WHERE clicks < 0
   OR transactions < 0
   OR approved_transactions < 0
   OR program_commission < 0
