-- Every valid voucher must balance: its line sums add up to zero.
--
-- Netvisor will not save an unbalanced voucher, so a failure points at the pipeline: a
-- voucher_line array that did not parse, a line sum that came through as text with a
-- decimal comma, or an invalidated voucher counted as valid. One cent of tolerance for
-- the float-to-decimal conversion.

SELECT
    voucher_key,
    voucher_number,
    SUM(amount) AS imbalance
FROM {{ ref('core_netvisor__general_ledger') }}
GROUP BY 1, 2
HAVING ABS(SUM(amount)) > 0.01
