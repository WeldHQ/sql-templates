-- amazon_seller_traffic_and_conversion - sessions, page views, Buy Box share and
-- conversion, at the grain each metric is actually measured on.
--
-- Grain: day x seller x marketplace x child ASIN. Currency: the marketplace's.
-- Depends on: staging.amazon_seller.sales_and_traffic_by_asin, .listings
--
-- WHY THIS MODEL IS AT ASIN GRAIN WHEN EVERYTHING ELSE IS AT SKU GRAIN. Because
-- that is where Amazon measures it. Sessions and page views are counted on a detail
-- page, and a detail page belongs to a child ASIN - not to a SKU. If two SKUs sit on
-- the same ASIN (the usual case for a restocked or repackaged product), Amazon
-- repeats the SAME session count on both rows of the SKU-grain report.
--
-- So SUM(sessions) over SKUs double-counts traffic, and every conversion rate
-- computed from it is understated by exactly that factor. This is the single most
-- common error in Amazon reporting after the report-generation duplicates, and it is
-- invisible: the numbers look plausible, just wrong, and they get worse the more
-- SKUs share an ASIN.
--
-- The fix is not clever. Roll traffic up with MAX per ASIN (every SKU row carries the
-- same value, so any one of them is the value) and units with SUM (those genuinely
-- are per SKU), then divide. Doing it in that order is the whole model.

WITH by_asin AS (
    SELECT
        t.date,
        t.amazon_seller,
        t.marketplace,
        t.parent_asin,
        t.child_asin,

        -- Traffic: MAX, not SUM. Identical across the SKUs of one ASIN.
        MAX(t.sessions)                 AS sessions,
        MAX(t.browser_sessions)         AS browser_sessions,
        MAX(t.mobile_app_sessions)      AS mobile_app_sessions,
        MAX(t.page_views)               AS page_views,
        MAX(t.browser_page_views)       AS browser_page_views,
        MAX(t.mobile_app_page_views)    AS mobile_app_page_views,
        MAX(t.sessions_b2b)             AS sessions_b2b,
        MAX(t.page_views_b2b)           AS page_views_b2b,

        -- Buy Box is a share of page views on the ASIN, so it is also per-ASIN.
        MAX(t.buy_box_percentage)       AS buy_box_percentage,

        -- Sales: SUM. Genuinely per SKU.
        SUM(t.units_ordered)            AS units_ordered,
        SUM(t.ordered_product_sales)    AS ordered_product_sales,
        SUM(t.total_order_items)        AS total_order_items,
        SUM(t.units_ordered_b2b)        AS units_ordered_b2b,
        SUM(t.ordered_product_sales_b2b) AS ordered_product_sales_b2b,

        COUNT(DISTINCT t.sku)           AS sku_count,
        ANY_VALUE(t.currency)           AS currency
    FROM {{staging.amazon_seller.sales_and_traffic_by_asin}} t
    GROUP BY 1, 2, 3, 4, 5
)

SELECT
    a.date,
    a.amazon_seller,
    a.marketplace,
    a.parent_asin,
    a.child_asin,
    a.currency,

    -- How many SKUs share this detail page. Anything above 1 is precisely the case
    -- that breaks a naive SKU-grain traffic query, so it is worth surfacing rather
    -- than hiding.
    a.sku_count,
    l.product_name,
    l.listing_status,

    a.sessions,
    a.browser_sessions,
    a.mobile_app_sessions,
    a.page_views,
    a.browser_page_views,
    a.mobile_app_page_views,

    -- Mobile share of sessions. Usually 60-75%, and worth knowing before anyone
    -- redesigns listing images for a desktop viewport.
    ROUND(SAFE_DIVIDE(a.mobile_app_sessions, NULLIF(a.sessions, 0)), 4) AS mobile_session_share,

    a.units_ordered,
    a.total_order_items,
    a.ordered_product_sales,

    -- Conversion, computed at the grain where both sides are correct: units per
    -- session for this ASIN. This is Amazon's unit_session_percentage, recomputed
    -- rather than averaged - averaging the per-SKU percentages weights a SKU that
    -- sold one unit the same as one that sold a thousand.
    ROUND(SAFE_DIVIDE(a.units_ordered, NULLIF(a.sessions, 0)), 4)       AS unit_session_rate,
    ROUND(SAFE_DIVIDE(a.total_order_items, NULLIF(a.sessions, 0)), 4)   AS order_item_session_rate,
    ROUND(SAFE_DIVIDE(a.ordered_product_sales, NULLIF(a.sessions, 0)), 4) AS revenue_per_session,
    ROUND(SAFE_DIVIDE(a.ordered_product_sales, NULLIF(a.units_ordered, 0)), 2) AS average_selling_price,

    -- Buy Box share. The lever nobody looks at: at 70% you are handing three in ten
    -- page views to another seller, and traffic spend on those views is wasted.
    a.buy_box_percentage,

    -- B2B is a SUBSET of the totals above, not additional to them. Consumer is the
    -- difference - stated explicitly because reading b2b as incremental is an easy
    -- and expensive mistake in a channel-mix analysis.
    a.units_ordered_b2b,
    a.ordered_product_sales_b2b,
    a.units_ordered - a.units_ordered_b2b                   AS units_ordered_consumer,
    a.ordered_product_sales - a.ordered_product_sales_b2b   AS ordered_product_sales_consumer,
    ROUND(SAFE_DIVIDE(a.ordered_product_sales_b2b, NULLIF(a.ordered_product_sales, 0)), 4) AS b2b_revenue_share,

    a.sessions_b2b,
    a.page_views_b2b
FROM by_asin a
-- One listing per ASIN for naming. A LEFT JOIN on a de-duplicated listings set:
-- joining the raw listings table would fan out for every SKU on the ASIN and undo
-- the roll-up this model exists to perform.
LEFT JOIN (
    SELECT
        amazon_seller,
        marketplace,
        asin,
        ANY_VALUE(product_name)   AS product_name,
        ANY_VALUE(listing_status)  AS listing_status
    FROM {{staging.amazon_seller.listings}}
    WHERE asin IS NOT NULL
    GROUP BY 1, 2, 3
) l
  ON  l.amazon_seller = a.amazon_seller
  AND l.marketplace   = a.marketplace
  AND l.asin          = a.child_asin
