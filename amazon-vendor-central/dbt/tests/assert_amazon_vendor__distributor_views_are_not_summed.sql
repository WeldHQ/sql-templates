-- Catches the mistake this whole template set is arranged to prevent: adding
-- MANUFACTURING and SOURCING together.
--
-- The two views describe OVERLAPPING sets of ASINs - an ASIN you manufacture and also
-- source appears under both, reporting the same units - so their sum is not a
-- business total. For most vendors it is close to a clean 2x, which is exactly big
-- enough to be noticed and exactly plausible enough to be believed.
--
-- The test does not inspect a dashboard; it cannot. What it does is measure the
-- OVERLAP, so you know the size of the error you would be making. It fails when a
-- material share of ASINs report shipped units under both views on the same day -
-- which is the condition under which summing is dangerous rather than merely wrong.
--
-- If it fires, that is information, not a defect: filter to one view. The analytics
-- models already do (MANUFACTURING + RETAIL); this test exists so that anyone
-- querying core directly finds out before publishing a number.

WITH overlap AS (
    SELECT
        date,
        amazon_vendor,
        marketplace,
        selling_program,
        asin,
        COUNT(DISTINCT distributor_view) AS view_count
    FROM {{ ref('stg_amazon_vendor__sales') }}
    WHERE shipped_units > 0
    GROUP BY 1, 2, 3, 4, 5
)

SELECT
    date,
    amazon_vendor,
    marketplace,
    selling_program,
    COUNT(*)                                                    AS asins_with_sales,
    COUNTIF(view_count > 1)                                     AS asins_in_both_views,
    ROUND(SAFE_DIVIDE(COUNTIF(view_count > 1), COUNT(*)), 4)     AS overlap_share
FROM overlap
GROUP BY 1, 2, 3, 4
-- More than a tenth of selling ASINs double-reported. Below that, the views are
-- genuinely disjoint for your catalogue and summing is merely untidy.
HAVING SAFE_DIVIDE(COUNTIF(view_count > 1), COUNT(*)) > 0.10
