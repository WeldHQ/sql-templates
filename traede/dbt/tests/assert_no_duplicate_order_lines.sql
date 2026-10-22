-- One row per order line in the order book.
--
-- Traede keys an order line by order and variant. A duplicate here means a join
-- fanned out (most often customer, variant or product appearing twice in staging,
-- or a second account added without its label in a join key) and every open value
-- on that order is counted twice.
--
-- Returns zero rows when the grain holds.

SELECT
    traede_account,
    order_id,
    variant_id,
    COUNT(*) AS row_count
FROM {{ ref('core_traede__order_book') }}
GROUP BY 1, 2, 3
HAVING COUNT(*) > 1
