-- core.traede.invoiced_sales_over_time
-- Invoiced wholesale revenue per day, from booked Traede invoices.
-- Grain: day x traede_account x currency. Amounts ex VAT unless named otherwise.
-- Depends on: staging.traede.invoice
--
-- WHY INVOICES, NOT ORDERS: in wholesale an order is booked months before it ships
-- and is often shipped in drops, part-cancelled or re-sized on the way. Revenue is
-- what was invoiced. Order intake and the open order book are in core.traede.order_book.
--
-- Only BOOKED invoices count. A draft has no invoice number, can still change and is
-- not revenue. Draft totals are returned separately so a backlog of unbooked drafts
-- is visible rather than silently missing.
--
-- CURRENCY is part of the grain because Traede invoices each customer in its own
-- currency and nothing in the synced data converts between them. Summing across
-- currencies gives a meaningless number; convert in BI or join your own FX table.
--
-- CREDIT NOTES ARE NOT DEDUCTED. They are a separate Traede resource the connector
-- does not sync, so this is gross invoiced revenue before credits.
--
-- Built on a day spine per account and currency so a day with no invoices returns
-- zeros instead of a gap a line chart would interpolate across.

WITH booked AS (
    SELECT *
    FROM {{staging.traede.invoice}}
    WHERE is_booked
),

series AS (
    -- One series per account and currency, from its first booked invoice to today,
    -- or to the last invoice date if an invoice is dated ahead.
    SELECT traede_account, currency, MIN(invoice_date) AS first_date, MAX(invoice_date) AS last_date
    FROM booked
    GROUP BY 1, 2
),

spine AS (
    SELECT s.traede_account, s.currency, d AS date
    FROM series s
    CROSS JOIN UNNEST(GENERATE_DATE_ARRAY(s.first_date, GREATEST(s.last_date, CURRENT_DATE()))) AS d
),

daily AS (
    SELECT
        invoice_date AS date,
        traede_account,
        currency,
        COUNT(*)                                          AS invoices,
        COUNT(DISTINCT customer_id)                       AS invoiced_customers,
        SUM(total_quantity)                               AS units_invoiced,
        SUM(gross_amount)                                 AS gross_sales,
        SUM(discount_amount)                              AS discounts,
        SUM(net_amount)                                   AS net_sales,
        SUM(shipping_amount)                              AS shipping,
        SUM(handling_fee_amount)                          AS handling_fees,
        SUM(vat_amount)                                   AS vat,
        SUM(total_incl_vat)                               AS total_incl_vat,
        -- Split by Traede order type so wholesale and webshop revenue can be read
        -- apart. order_type defaults to b2b in Traede, so a NULL is counted there.
        SUM(CASE WHEN COALESCE(order_type, 'b2b') = 'b2b' THEN net_amount END) AS b2b_net_sales,
        SUM(CASE WHEN order_type = 'b2c' THEN net_amount END)                  AS b2c_net_sales,
        SUM(CASE WHEN order_type NOT IN ('b2b', 'b2c') THEN net_amount END)    AS other_net_sales
    FROM booked
    GROUP BY 1, 2, 3
),

drafts AS (
    SELECT
        invoice_date AS date,
        traede_account,
        currency,
        COUNT(*)        AS draft_invoices,
        SUM(net_amount) AS draft_net_amount
    FROM {{staging.traede.invoice}}
    WHERE NOT is_booked
    GROUP BY 1, 2, 3
)

SELECT
    s.date,
    s.traede_account,
    s.currency,
    COALESCE(d.invoices, 0)            AS invoices,
    COALESCE(d.invoiced_customers, 0)  AS invoiced_customers,
    COALESCE(d.units_invoiced, 0)      AS units_invoiced,
    COALESCE(d.gross_sales, 0)         AS gross_sales,
    COALESCE(d.discounts, 0)           AS discounts,
    COALESCE(d.net_sales, 0)           AS net_sales,
    COALESCE(d.shipping, 0)            AS shipping,
    COALESCE(d.handling_fees, 0)       AS handling_fees,
    COALESCE(d.vat, 0)                 AS vat,
    COALESCE(d.total_incl_vat, 0)      AS total_incl_vat,
    COALESCE(d.b2b_net_sales, 0)       AS b2b_net_sales,
    COALESCE(d.b2c_net_sales, 0)       AS b2c_net_sales,
    COALESCE(d.other_net_sales, 0)     AS other_net_sales,
    -- Drafts dated on a day that has no booked invoices in the same currency fall
    -- outside the spine and are not returned; this column is a backlog signal, not
    -- a ledger.
    COALESCE(x.draft_invoices, 0)      AS draft_invoices,
    COALESCE(x.draft_net_amount, 0)    AS draft_net_amount
FROM spine s
LEFT JOIN daily d
       ON d.traede_account = s.traede_account
      AND d.currency       = s.currency
      AND d.date           = s.date
LEFT JOIN drafts x
       ON x.traede_account = s.traede_account
      AND x.currency       = s.currency
      AND x.date           = s.date
