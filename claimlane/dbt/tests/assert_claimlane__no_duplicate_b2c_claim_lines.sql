-- One row per product line per consumer ticket.
--
-- A duplicate means the refund aggregation stopped being one row per line, or a
-- second Claimlane connection was unioned into staging without changing the
-- claimlane_account label. Either one multiplies claimed value and refunds.

SELECT
    claimlane_account,
    ticket_id,
    product_index,
    COUNT(*) AS rows_for_line
FROM {{ ref('core_claimlane__b2c_claim_lines') }}
GROUP BY 1, 2, 3
HAVING COUNT(*) > 1
