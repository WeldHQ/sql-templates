-- The line-grain model must track Amazon's own Business Report, month by month.
--
-- NOT AN EQUALITY TEST, AND IT CANNOT BE. Amazon does not document the cancellation
-- and pending-order logic behind ordered_product_sales, so a model built from order
-- lines will land close to it but never exactly on it. Expect a fraction of a
-- percent.
--
-- What this test catches is DRIFT: a gap that grows, which means a structural problem
-- (a channel excluded, a marketplace missing, cancellations handled differently)
-- rather than a rounding difference. The 2% threshold is a starting point - measure
-- your own steady-state gap over a few closed months and tighten it to just above
-- that. Left loose it will never fire; tightened correctly it is an early warning
-- that a report changed shape.
--
-- Closed months only. The current month is mid-restatement on both sides and would
-- fail every day until it ends.

WITH business_report AS (
    SELECT
        DATE_TRUNC(date, MONTH) AS month,
        amazon_seller,
        marketplace,
        SUM(ordered_product_sales) AS reported_sales
    FROM {{ ref('core_amazon_seller__sales_over_time') }}
    WHERE date < DATE_TRUNC(CURRENT_DATE(), MONTH)
    GROUP BY 1, 2, 3
),

modelled AS (
    SELECT
        DATE_TRUNC(date, MONTH) AS month,
        amazon_seller,
        marketplace,
        -- SALE rows only: ordered_product_sales is a demand figure on the order date
        -- and does not net out later returns, so comparing it to a net number that
        -- includes RETURN rows is not a like-for-like test.
        SUM(CASE WHEN report_row_type = 'SALE' THEN net_sales ELSE 0 END) AS modelled_sales
    FROM {{ ref('core_amazon_seller__product_sales_over_time') }}
    WHERE date < DATE_TRUNC(CURRENT_DATE(), MONTH)
    GROUP BY 1, 2, 3
)

SELECT
    b.month,
    b.amazon_seller,
    b.marketplace,
    b.reported_sales,
    m.modelled_sales,
    ROUND(COALESCE(m.modelled_sales, 0) - b.reported_sales, 2) AS diff,
    ROUND(SAFE_DIVIDE(COALESCE(m.modelled_sales, 0) - b.reported_sales,
                      NULLIF(b.reported_sales, 0)), 4)         AS diff_rate
FROM business_report b
LEFT JOIN modelled m USING (month, amazon_seller, marketplace)
WHERE ABS(SAFE_DIVIDE(COALESCE(m.modelled_sales, 0) - b.reported_sales,
                      NULLIF(b.reported_sales, 0))) > 0.02
