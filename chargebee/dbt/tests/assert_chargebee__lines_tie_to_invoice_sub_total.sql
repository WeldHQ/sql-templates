-- Invoice lines net of discounts add up to the invoice sub_total.
--
-- Chargebee defines sub_total as the sum of line amounts minus the sum of line
-- discounts. The MRR models depend on that: they read `amount - discount_amount`
-- from each line as its share of revenue. If this fires, either a discount sits
-- at invoice level without being allocated to lines, or lines are missing from
-- the sync for those invoices. Either way MRR built from lines will not match
-- what was invoiced. A one-unit tolerance absorbs rounding.

WITH lines AS (
    SELECT invoice_id, SUM(net_amount) AS line_net_amount
    FROM {{ ref('stg_chargebee__invoice_line_item') }}
    GROUP BY 1
)

SELECT
    i.invoice_id,
    i.currency,
    i.sub_total,
    l.line_net_amount
FROM {{ ref('stg_chargebee__invoice') }} i
JOIN lines l
  ON l.invoice_id = i.invoice_id
WHERE ABS(i.sub_total - l.line_net_amount) > 0.01 * (100 / i.minor_unit_divisor)
