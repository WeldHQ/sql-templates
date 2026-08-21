-- core_amazon_vendor__sales_by_asin - sales, traffic and Amazon's margin on one row per
-- ASIN per day. The vendor equivalent of a product performance report.
--
-- Grain: day x vendor x marketplace x distributor view x selling program x ASIN.
-- Currency: the marketplace's.
-- Depends on: stg_amazon_vendor__sales, .traffic, .margin
--
-- WHY THE JOIN IS THE WHOLE MODEL. Amazon reports vendor sales, vendor traffic and
-- vendor margin as three separate report types, on three separate schedules, and
-- gives you no way to see them together. Conversion is the ratio of a number in the
-- first to a number in the second; whether a well-converting ASIN is one Amazon
-- makes money on is in the third. Individually each report answers almost nothing.
--
-- TWO JOIN HAZARDS, both quiet:
--
--   * Traffic and margin are NOT reported per distributor view or selling program -
--     they are per ASIN per day, full stop. So joining them onto sales, which IS
--     split four ways, repeats the same glance views against each variant. Sum
--     glance_views across distributor views and you multiply traffic by up to four.
--     Filter to one view - the grain warns you, it cannot stop you.
--
--   * LEFT JOIN from sales, not INNER. An ASIN can sell with no glance views
--     recorded, and traffic reports lag sales by a day or more. INNER JOIN silently
--     drops the newest day of sales, which is the day someone is looking at.

{{ config(
    materialized='table',
    partition_by={'field': 'date', 'data_type': 'date', 'granularity': 'month'}
) }}

WITH sales AS (
    SELECT
        date, amazon_vendor, marketplace, distributor_view, selling_program, asin,
        currency,
        SUM(shipped_cogs)      AS shipped_cogs,
        SUM(shipped_revenue)   AS shipped_revenue,
        SUM(shipped_units)     AS shipped_units,
        SUM(ordered_revenue)   AS ordered_revenue,
        SUM(ordered_units)     AS ordered_units,
        SUM(customer_returns)  AS customer_returns
    FROM {{ ref('stg_amazon_vendor__sales') }}
    GROUP BY 1, 2, 3, 4, 5, 6, 7
)

SELECT
    s.date,
    s.amazon_vendor,
    s.marketplace,
    s.distributor_view,
    s.selling_program,
    s.asin,
    s.currency,

    ROUND(s.shipped_cogs, 2)        AS shipped_cogs,
    s.shipped_units,
    ROUND(s.shipped_revenue, 2)     AS shipped_revenue,
    ROUND(s.ordered_revenue, 2)     AS ordered_revenue,
    s.ordered_units,
    s.customer_returns,

    ROUND(SAFE_DIVIDE(s.shipped_cogs, NULLIF(s.shipped_units, 0)), 2)    AS cogs_per_unit,
    ROUND(SAFE_DIVIDE(s.shipped_revenue, NULLIF(s.shipped_units, 0)), 2) AS retail_price_per_unit,

    -- Traffic. See the header: repeated across distributor views, so filter to one.
    t.glance_views,

    -- Conversion. The metric this model exists for, and the one Vendor Central makes
    -- you compute yourself. Ordered units, not shipped, because conversion is about
    -- the moment of the sale - shipping happens later and out of your control.
    ROUND(SAFE_DIVIDE(s.ordered_units, NULLIF(t.glance_views, 0)), 4)    AS conversion_rate,
    ROUND(SAFE_DIVIDE(s.ordered_revenue, NULLIF(t.glance_views, 0)), 4)  AS revenue_per_glance_view,

    -- Amazon's margin on this ASIN, from the margin report. Amazon's, not yours -
    -- see stg_amazon_vendor__margin.
    m.net_pure_product_margin       AS amazon_net_pure_product_margin,

    -- Amazon's gross markup, derivable from the sales report alone, so it is
    -- available on days the margin report has not landed.
    ROUND(SAFE_DIVIDE(s.shipped_revenue - s.shipped_cogs,
                      NULLIF(s.shipped_revenue, 0)), 4) AS amazon_gross_markup_rate,

    -- Flags for the two states worth alerting on, distinguished because the remedy
    -- differs completely: traffic with no sales is a listing or price problem, sales
    -- with no traffic is a reporting gap.
    t.glance_views > 0 AND COALESCE(s.ordered_units, 0) = 0 AS has_traffic_no_orders,
    t.glance_views IS NULL                                  AS missing_traffic_data
FROM sales s
LEFT JOIN {{ ref('stg_amazon_vendor__traffic') }} t
       ON  t.amazon_vendor = s.amazon_vendor
       AND t.marketplace   = s.marketplace
       AND t.date          = s.date
       AND t.asin          = s.asin
LEFT JOIN {{ ref('stg_amazon_vendor__margin') }} m
       ON  m.amazon_vendor = s.amazon_vendor
       AND m.marketplace   = s.marketplace
       AND m.date          = s.date
       AND m.asin          = s.asin
