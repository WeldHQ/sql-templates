-- Every voucher must balance: debits equal credits, so the signed amounts sum to zero.
--
-- Fortnox refuses to save a voucher that does not balance, so a failure here is almost
-- always on our side: a removed (struck-through) row counted, a voucher row deduplicated
-- on the wrong key, or a voucher whose rows synced only partly. Half an öre of tolerance
-- for floating point.

SELECT
    financial_year_id,
    voucher_series,
    voucher_number,
    SUM(amount) AS imbalance
FROM {{ ref('core_fortnox__general_ledger') }}
GROUP BY 1, 2, 3
HAVING ABS(SUM(amount)) > 0.005
