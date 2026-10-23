-- One row per month and currency in the MRR bridge.

SELECT month, currency, COUNT(*) AS rows_at_grain
FROM {{ ref('core_chartmogul__mrr_movements') }}
GROUP BY 1, 2
HAVING COUNT(*) > 1
