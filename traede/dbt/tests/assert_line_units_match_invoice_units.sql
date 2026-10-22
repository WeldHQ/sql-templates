-- Units on booked invoice lines must add up to the units on the invoice headers,
-- day by day and currency by currency.
--
-- Traede's invoice header carries total_quantity, the total invoiced quantity, so
-- the two models should agree exactly. A gap usually means invoice lines failed to
-- sync for some invoices, or the invoice join lost the account label. Money is not
-- compared here: a discount set on the invoice header rather than on lines
-- legitimately makes line revenue differ from header revenue.
--
-- Returns zero rows when they agree.

WITH header AS (
    SELECT date, traede_account, currency, SUM(units_invoiced) AS units
    FROM {{ ref('core_traede__invoiced_sales_over_time') }}
    GROUP BY 1, 2, 3
),

lines AS (
    SELECT date, traede_account, currency, SUM(units) AS units
    FROM {{ ref('core_traede__product_sales') }}
    GROUP BY 1, 2, 3
)

SELECT
    COALESCE(h.date, l.date)                     AS date,
    COALESCE(h.traede_account, l.traede_account) AS traede_account,
    COALESCE(h.currency, l.currency)             AS currency,
    h.units                                      AS header_units,
    l.units                                      AS line_units
FROM header h
FULL OUTER JOIN lines l
  ON l.date           = h.date
 AND l.traede_account = h.traede_account
 AND l.currency       = h.currency
WHERE COALESCE(h.units, 0) <> COALESCE(l.units, 0)
