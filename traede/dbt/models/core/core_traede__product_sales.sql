-- core_traede__product_sales
-- Invoiced units, revenue, cost and gross margin per variant per day.
-- Grain: day x traede_account x currency x variant.
-- Depends on: staging.traede.invoice, .invoice_line, .variant, .product
--
-- Read from booked invoice LINES on the invoice date. Revenue here is line net
-- (after line discount, ex VAT). It does not include shipping or handling, and it
-- will sit below invoiced_sales_over_time.net_sales by any discount applied on the
-- invoice header rather than on lines.
--
-- COST AND MARGIN. Cost is the variant's CURRENT cost_price from Traede x units.
-- Two limits follow:
--   1. It is today's cost, not the cost when the goods were sold.
--   2. Traede does not document which currency cost_price is in. It is normally the
--      account's base currency. Set base_currency below to yours. Margin is only
--      computed for invoice lines in that currency; lines in other currencies get
--      NULL cost and margin rather than a number that subtracts EUR from SEK.
-- unit_landed_cost is returned alongside, for brands that report margin after
-- freight and duty.
--
-- No margin percentage is returned per row. Average it in BI as
-- SUM(gross_margin) / SUM(net_sales_with_cost); averaging row percentages weights
-- a one-unit day the same as a thousand-unit day.

WITH settings AS (
    SELECT 'EUR' AS base_currency   -- change to your Traede account's base currency
),

lines AS (
    SELECT
        i.invoice_date AS date,
        i.traede_account,
        i.currency,
        i.invoice_id,
        l.product_id,
        l.variant_id,
        l.quantity,
        l.line_gross_amount,
        l.line_discount_amount,
        l.line_net_amount
    FROM {{ ref('stg_traede__invoice_line') }} l
    JOIN {{ ref('stg_traede__invoice') }} i
      ON i.traede_account = l.traede_account
     AND i.invoice_id     = l.invoice_id
    WHERE i.is_booked
),

agg AS (
    SELECT
        date,
        traede_account,
        currency,
        variant_id,
        -- A variant belongs to one product; ANY_VALUE avoids putting product_id in
        -- the grain where a NULL on some lines would split the row.
        ANY_VALUE(product_id)            AS product_id,
        COUNT(DISTINCT invoice_id)       AS invoices,
        SUM(quantity)                    AS units,
        SUM(line_gross_amount)           AS gross_sales,
        SUM(line_discount_amount)        AS discounts,
        SUM(line_net_amount)             AS net_sales
    FROM lines
    GROUP BY 1, 2, 3, 4
)

SELECT
    a.date,
    a.traede_account,
    a.currency,
    a.variant_id,
    a.product_id,
    p.item_number,
    p.product_name,
    v.sku,
    v.ean,
    a.invoices,
    a.units,
    a.gross_sales,
    a.discounts,
    a.net_sales,
    v.unit_cost_price,
    v.unit_landed_cost,
    a.currency = st.base_currency AS is_cost_currency_match,
    CASE WHEN a.currency = st.base_currency THEN a.net_sales END            AS net_sales_with_cost,
    CASE WHEN a.currency = st.base_currency THEN a.units * v.unit_cost_price END AS cost_amount,
    CASE WHEN a.currency = st.base_currency
         THEN a.net_sales - a.units * v.unit_cost_price END                 AS gross_margin
FROM agg a
CROSS JOIN settings st
LEFT JOIN {{ ref('stg_traede__variant') }} v
       ON v.traede_account = a.traede_account
      AND v.variant_id     = a.variant_id
LEFT JOIN {{ ref('stg_traede__product') }} p
       ON p.traede_account = a.traede_account
      AND p.product_id     = a.product_id
