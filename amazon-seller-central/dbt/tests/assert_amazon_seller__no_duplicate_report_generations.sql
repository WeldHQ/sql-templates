-- One row per date per marketplace in the Business Report staging model.
--
-- The de-duplication in stg_amazon_seller__sales_and_traffic_by_date is the single
-- most load-bearing line in the staging layer: Amazon re-generates this report on
-- every sync and Weld appends each generation, so without it a recent day is counted
-- once per fetch. This test is here because the failure mode is silent - the numbers
-- stay plausible, they are just multiples of the truth, and the multiple grows the
-- more often you sync.
--
-- If this fires, the ROW_NUMBER() partition no longer matches the report's actual
-- grain. Usually that means the stream was switched from DAY to WEEK or MONTH
-- granularity, in which case the fix is in the staging model's grain, not here.

SELECT
    date,
    amazon_seller,
    marketplace,
    COUNT(*) AS row_count
FROM {{ ref('stg_amazon_seller__sales_and_traffic_by_date') }}
GROUP BY 1, 2, 3
HAVING COUNT(*) > 1
