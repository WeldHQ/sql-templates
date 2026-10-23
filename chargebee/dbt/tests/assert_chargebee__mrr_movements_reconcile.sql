-- The MRR bridge holds on every customer row, and the monthly model sums back to
-- the customer model.
--
--   beginning_mrr + new + expansion + contraction + churned + reactivation = ending_mrr
--
-- If the first half fires, the movement classification in
-- core_chargebee__mrr_by_customer_month has a gap: some combination of
-- beginning and ending MRR falls into no bucket, so money moved without being
-- explained. If the second half fires, mrr_movements is no longer a plain sum of
-- the customer rows. Rows returned are the offending months.

WITH customer_rows AS (
    SELECT
        month,
        currency,
        customer_id,
        beginning_mrr + new_mrr + expansion_mrr + contraction_mrr
          + churned_mrr + reactivation_mrr - ending_mrr          AS difference
    FROM {{ ref('core_chargebee__mrr_by_customer_month') }}
),

customer_totals AS (
    SELECT month, currency, SUM(ending_mrr) AS ending_mrr
    FROM {{ ref('core_chargebee__mrr_by_customer_month') }}
    GROUP BY 1, 2
)

SELECT month, currency, customer_id, difference
FROM customer_rows
WHERE ABS(difference) > 0.01

UNION ALL

SELECT m.month, m.currency, CAST(NULL AS STRING), m.ending_mrr - c.ending_mrr
FROM {{ ref('core_chargebee__mrr_movements') }} m
JOIN customer_totals c
  ON c.month = m.month AND c.currency = m.currency
WHERE ABS(m.ending_mrr - c.ending_mrr) > 0.01
