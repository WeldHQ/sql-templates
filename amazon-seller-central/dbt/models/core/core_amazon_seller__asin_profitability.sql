-- core_amazon_seller__asin_profitability - contribution margin per SKU per day, after
-- Amazon's fees, returns and your COGS.
--
-- Grain: day x seller x marketplace x ASIN x SKU. Currency: the marketplace's.
-- Depends on: core_amazon_seller__product_sales_over_time,
--             core_amazon_seller__settlement_ledger,
--             stg_amazon_seller__fba_reimbursements, .sku_cost
--
-- THE MODEL EVERY AMAZON SELLER WANTS AND ALMOST NONE HAS, because it needs three
-- reports that do not join to each other and disagree about what day it is:
--
--   sales      attributed to the ORDER date
--   fees       attributed to the SETTLEMENT date, days or weeks later
--   returns    attributed to the RETURN date, weeks later still
--
-- There is no correct way to reconcile those on a single day, and pretending
-- otherwise is the usual bug: joining fees to sales by date makes a SKU look
-- gloriously profitable on order day and catastrophic on settlement day.
--
-- WHAT THIS MODEL DOES INSTEAD: it keeps each component on its own date and adds
-- them up over a WINDOW. Each column is honest about which event it counts, and
-- contribution is only meaningful once aggregated over a period long enough to
-- contain both the sale and its settlement - a month, in practice, and never a day.
-- Read a single row and you are reading a cash-flow event, not a margin.
--
-- Weekly and monthly rollups are in core; put anything shorter in front of a
-- warning label.

{{ config(
    materialized='table',
    partition_by={'field': 'date', 'data_type': 'date', 'granularity': 'month'}
) }}

WITH sales AS (
    SELECT
        date, amazon_seller, marketplace, asin, sku,
        product_name,
        SUM(CASE WHEN report_row_type = 'SALE' THEN quantity ELSE 0 END)   AS units_sold,
        SUM(CASE WHEN report_row_type = 'SALE' THEN net_sales ELSE 0 END)  AS gross_revenue,
        SUM(CASE WHEN report_row_type = 'RETURN' THEN returns ELSE 0 END)  AS returned_revenue,
        SUM(returned_quantity)                                            AS returned_units,
        SUM(resellable_returned_quantity)                                 AS resellable_returned_units,
        SUM(return_label_cost)                                            AS return_label_cost
    FROM {{ ref('core_amazon_seller__product_sales_over_time') }}
    GROUP BY 1, 2, 3, 4, 5, 6
),

-- SKU-attributable fees only. Account-level charges are excluded here on purpose:
-- allocating storage and advertising across SKUs by revenue share invents a number
-- and then buries the assumption. They are reported separately below.
fees AS (
    SELECT
        date, amazon_seller, marketplace, sku,
        SUM(selling_fees)      AS selling_fees,
        SUM(fba_fees)          AS fba_fees,
        SUM(service_fees)      AS service_fees,
        SUM(advertising_cost)  AS advertising_cost,
        SUM(refunded_fees)     AS refunded_fees,
        SUM(net_proceeds)      AS net_proceeds,
        SUM(units_settled)     AS units_settled
    FROM {{ ref('core_amazon_seller__settlement_ledger') }}
    WHERE NOT is_account_level
    GROUP BY 1, 2, 3, 4
),

reimbursements AS (
    SELECT
        approval_date AS date, amazon_seller, sku,
        SUM(reimbursed_amount)         AS reimbursed_amount,
        SUM(quantity_reimbursed_total) AS reimbursed_units
    FROM {{ ref('stg_amazon_seller__fba_reimbursements') }}
    GROUP BY 1, 2, 3
),

base AS (
    SELECT
        COALESCE(s.date, f.date, r.date)                             AS date,
        COALESCE(s.amazon_seller, f.amazon_seller, r.amazon_seller)  AS amazon_seller,
        COALESCE(s.marketplace, f.marketplace)                       AS marketplace,
        s.asin,
        COALESCE(s.sku, f.sku, r.sku)                                AS sku,
        s.product_name,

        COALESCE(s.units_sold, 0)                 AS units_sold,
        COALESCE(s.gross_revenue, 0)              AS gross_revenue,
        COALESCE(s.returned_revenue, 0)           AS returned_revenue,
        COALESCE(s.returned_units, 0)             AS returned_units,
        COALESCE(s.resellable_returned_units, 0)  AS resellable_returned_units,
        COALESCE(s.return_label_cost, 0)          AS return_label_cost,

        COALESCE(f.selling_fees, 0)               AS selling_fees,
        COALESCE(f.fba_fees, 0)                   AS fba_fees,
        COALESCE(f.service_fees, 0)               AS service_fees,
        COALESCE(f.advertising_cost, 0)           AS advertising_cost,
        COALESCE(f.refunded_fees, 0)              AS refunded_fees,
        COALESCE(f.net_proceeds, 0)               AS net_proceeds,
        COALESCE(f.units_settled, 0)              AS units_settled,

        COALESCE(r.reimbursed_amount, 0)          AS reimbursed_amount,
        COALESCE(r.reimbursed_units, 0)           AS reimbursed_units
    -- FULL OUTER, three ways: a settlement can post on a day with no sale, a
    -- reimbursement can post months after either. An inner join here silently drops
    -- fees for old orders, which flatters margin by exactly the amount you most want
    -- to see.
    FROM sales s
    FULL OUTER JOIN fees f
      ON  f.date          = s.date
      AND f.amazon_seller = s.amazon_seller
      AND f.marketplace   = s.marketplace
      AND f.sku           = s.sku
    FULL OUTER JOIN reimbursements r
      ON  r.date          = COALESCE(s.date, f.date)
      AND r.amazon_seller = COALESCE(s.amazon_seller, f.amazon_seller)
      AND r.sku           = COALESCE(s.sku, f.sku)
)

SELECT
    b.date,
    b.amazon_seller,
    b.marketplace,
    b.asin,
    b.sku,
    b.product_name,

    b.units_sold,
    b.units_settled,
    b.returned_units,
    b.resellable_returned_units,

    -- Units that came back and cannot be resold. These are the expensive ones: the
    -- COGS is gone as well as the fees. returned_units is negative (the reversal
    -- convention), resellable is a positive count, so this is ABS minus recovered -
    -- reported positive because it is a quantity written off, not a reversal.
    ABS(b.returned_units) - b.resellable_returned_units AS unrecoverable_returned_units,

    ROUND(b.gross_revenue, 2)                     AS gross_revenue,
    ROUND(b.returned_revenue, 2)                  AS returned_revenue,
    ROUND(b.gross_revenue + b.returned_revenue, 2) AS net_revenue,

    ROUND(b.selling_fees, 2)                      AS selling_fees,
    ROUND(b.fba_fees, 2)                          AS fba_fees,
    ROUND(b.service_fees, 2)                      AS service_fees,
    ROUND(b.advertising_cost, 2)                  AS advertising_cost,
    ROUND(b.refunded_fees, 2)                     AS refunded_fees,
    ROUND(b.return_label_cost, 2)                 AS return_label_cost,
    ROUND(b.reimbursed_amount, 2)                 AS reimbursements,

    ROUND(b.selling_fees + b.fba_fees + b.service_fees
          + b.advertising_cost + b.refunded_fees, 2) AS total_amazon_fees,

    -- COGS, from stg_amazon_seller__sku_cost, valued at the cost that was in
    -- effect on the day of the sale. NULL until you populate that model, and NULL is
    -- deliberate: a zero would render as a healthy margin and get quoted.
    ROUND(b.units_sold * c.unit_cost, 2)          AS cogs,

    -- Returned units release their cost back into inventory only if they came back
    -- sellable, so the write-off is the unrecoverable share. Positive: a cost, to be
    -- subtracted below alongside cogs.
    ROUND((ABS(b.returned_units) - b.resellable_returned_units) * c.unit_cost, 2) AS returned_cogs_writeoff,

    -- Contribution after Amazon. Available without COGS, which is why it is a
    -- separate column - most sellers can compute this on day one and margin only
    -- later.
    ROUND(b.gross_revenue + b.returned_revenue
          + b.selling_fees + b.fba_fees + b.service_fees
          + b.advertising_cost + b.refunded_fees
          + b.return_label_cost + b.reimbursed_amount, 2) AS contribution_after_amazon,

    -- Contribution after Amazon and COGS. The actual answer. NULL without cost data.
    ROUND(b.gross_revenue + b.returned_revenue
          + b.selling_fees + b.fba_fees + b.service_fees
          + b.advertising_cost + b.refunded_fees
          + b.return_label_cost + b.reimbursed_amount
          - (b.units_sold * c.unit_cost)
          - ((ABS(b.returned_units) - b.resellable_returned_units) * c.unit_cost), 2) AS contribution_margin,

    ROUND(SAFE_DIVIDE(
        b.gross_revenue + b.returned_revenue
          + b.selling_fees + b.fba_fees + b.service_fees
          + b.advertising_cost + b.refunded_fees
          + b.return_label_cost + b.reimbursed_amount,
        NULLIF(b.gross_revenue, 0)), 4)           AS contribution_after_amazon_rate,

    ROUND(SAFE_DIVIDE(ABS(b.returned_revenue), NULLIF(b.gross_revenue, 0)), 4) AS return_rate_value,
    ROUND(SAFE_DIVIDE(ABS(b.returned_units), NULLIF(b.units_sold, 0)), 4)      AS return_rate_units,

    -- TRUE when this row has fees or a reimbursement but no sale - a settlement or
    -- adjustment landing after the fact. Expected, and the reason a single day's
    -- margin is meaningless.
    b.units_sold = 0 AND (b.selling_fees <> 0 OR b.fba_fees <> 0 OR b.reimbursed_amount <> 0)
                                                  AS is_trailing_adjustment
FROM base b
-- Point-in-time cost: the window that contains the sale date, not today's price.
LEFT JOIN {{ ref('stg_amazon_seller__sku_cost') }} c
       ON  c.amazon_seller = b.amazon_seller
       AND c.sku           = b.sku
       AND b.date >= c.valid_from
       AND (c.valid_to IS NULL OR b.date < c.valid_to)
