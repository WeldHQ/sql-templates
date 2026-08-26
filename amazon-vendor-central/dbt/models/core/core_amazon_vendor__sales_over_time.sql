-- core_amazon_vendor__sales_over_time - the vendor sales report, one row per day, with the
-- three revenue definitions separated and Amazon's markup made explicit.
--
-- Grain: day x vendor x marketplace x distributor view x selling program.
-- Currency: the marketplace's.
-- Depends on: stg_amazon_vendor__sales
--
-- THE THING TO UNDERSTAND BEFORE READING ANY COLUMN: as a vendor you have two
-- different revenues and only one of them is yours.
--
--   shipped_cogs      what AMAZON PAYS YOU. Your revenue. This is the number that
--                     belongs in your P&L, and it is called "cost of goods sold"
--                     because it is Amazon's COGS, not yours. The naming has caused
--                     more confusion in vendor reporting than anything else.
--   shipped_revenue   what AMAZON CHARGES THE CUSTOMER. Amazon's revenue. Useful for
--                     market share and price monitoring, and not yours.
--   ordered_revenue   customer demand at Amazon's retail price, on the order date.
--                     Leading indicator. Populated on the MANUFACTURING view only.
--
-- Report your own top line off shipped_cogs. Every vendor that has ever presented a
-- suspiciously excellent Amazon quarter reported shipped_revenue by mistake.
--
-- THE GRAIN INCLUDES distributor_view AND selling_program because Amazon's four
-- report variants OVERLAP - MANUFACTURING and SOURCING can describe the same ASIN
-- and the same units. They are in the grain so that no dashboard can sum across them
-- by accident. Pick one view in your BI filter; MANUFACTURING + RETAIL is the usual
-- answer.

{{ config(materialized='table') }}

SELECT
    s.date,
    s.amazon_vendor,
    s.marketplace,
    s.distributor_view,
    s.selling_program,
    s.currency,

    -- Yours.
    ROUND(SUM(s.shipped_cogs), 2)               AS shipped_cogs,
    SUM(s.shipped_units)                        AS shipped_units,
    ROUND(SAFE_DIVIDE(SUM(s.shipped_cogs), NULLIF(SUM(s.shipped_units), 0)), 2) AS average_cogs_per_unit,

    -- Amazon's.
    ROUND(SUM(s.shipped_revenue), 2)            AS shipped_revenue,
    ROUND(SAFE_DIVIDE(SUM(s.shipped_revenue), NULLIF(SUM(s.shipped_units), 0)), 2) AS average_retail_price,

    -- Demand.
    ROUND(SUM(s.ordered_revenue), 2)            AS ordered_revenue,
    SUM(s.ordered_units)                        AS ordered_units,

    -- Amazon's gross markup on your product: retail minus wholesale, over retail.
    -- Not the same thing as net_pure_product_margin, which also nets out co-op
    -- funding; this one is visible from the sales report alone and moves whenever
    -- Amazon reprices. A sharp drop means Amazon is discounting into its own margin,
    -- which is usually a precursor to asking you to fund it.
    ROUND(SAFE_DIVIDE(SUM(s.shipped_revenue) - SUM(s.shipped_cogs),
                      NULLIF(SUM(s.shipped_revenue), 0)), 4) AS amazon_gross_markup_rate,

    -- Demand versus fulfilment. Persistently ordered > shipped means Amazon wanted
    -- more than it could ship - lost sales, and the report where you can prove it.
    SUM(s.ordered_units) - SUM(s.shipped_units) AS ordered_minus_shipped_units,
    ROUND(SAFE_DIVIDE(SUM(s.shipped_units), NULLIF(SUM(s.ordered_units), 0)), 4) AS shipped_to_ordered_ratio,

    -- Returns. Negative, per the staging convention, so shipped + returns is plain
    -- addition. Reported on the RETURN date, so this row's returns belong to earlier
    -- shipments - the rate below is a period ratio, not a cohort return rate.
    SUM(s.customer_returns)                     AS customer_returns,
    SUM(s.shipped_units + s.customer_returns)   AS net_shipped_units,
    ROUND(SAFE_DIVIDE(ABS(SUM(s.customer_returns)), NULLIF(SUM(s.shipped_units), 0)), 4) AS return_rate_units,

    COUNT(DISTINCT s.asin)                      AS asins_with_sales
FROM {{ ref('stg_amazon_vendor__sales') }} s
GROUP BY s.date, s.amazon_vendor, s.marketplace, s.distributor_view,
         s.selling_program, s.currency
