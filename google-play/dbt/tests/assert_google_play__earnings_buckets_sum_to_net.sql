-- The named earnings buckets plus other_amounts equal net_earnings on every row.
-- net_earnings is a plain sum of Google's signed lines, so this only fails if a
-- bucket double-counts a transaction type or a type is caught by none of them.

SELECT *
FROM {{ ref('core_google_play__earnings_monthly') }}
WHERE ABS(
    gross_charges + charge_refunds + google_fees + google_fee_refunds + taxes + other_amounts
    - net_earnings
) > 0.01
