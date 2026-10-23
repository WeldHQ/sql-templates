-- One row per month x customer x currency in the customer MRR model.
--
-- A duplicate here means a customer is counted twice in the bridge, which
-- inflates MRR silently. The usual cause is a staging model losing its
-- de-duplication, or a join to customer that is no longer unique.

SELECT
    month,
    customer_id,
    currency,
    COUNT(*) AS row_count
FROM {{ ref('core_chargebee__mrr_by_customer_month') }}
GROUP BY 1, 2, 3
HAVING COUNT(*) > 1
