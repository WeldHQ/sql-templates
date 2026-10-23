-- One row per order in order_fulfillment.
--
-- Shipments, labels, line items and shipping lines are each aggregated to the
-- order before they are joined. A duplicate here means one of those CTEs lost its
-- GROUP BY or a join lost the shiphero_account key, and units and label cost on
-- that order are multiplied.
--
-- Returns zero rows when the grain holds.

SELECT
    shiphero_account,
    order_id,
    COUNT(*) AS row_count
FROM {{ ref('core_shiphero__order_fulfillment') }}
GROUP BY 1, 2
HAVING COUNT(*) > 1
