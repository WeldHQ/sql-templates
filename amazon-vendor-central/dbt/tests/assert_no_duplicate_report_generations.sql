-- One row per date x ASIN x distributor view x selling program in the vendor sales
-- staging model.
--
-- Amazon re-generates the vendor retail analytics reports on every sync and restates
-- the trailing ~72 hours; Weld appends each generation. The de-duplication in
-- stg_amazon_vendor__sales is what stops a recent day being counted once per fetch,
-- and this test is here because that failure is silent - shipped_cogs stays
-- plausible, it is just a multiple of the truth.
--
-- If this fires, the ROW_NUMBER() partition no longer matches the report's grain.
-- The usual cause is the stream being switched from DAY to WEEK or MONTH period, in
-- which case start_date and end_date are a range and collapsing to start_date is
-- wrong - fix the grain in staging, not here.

SELECT
    date,
    amazon_vendor,
    marketplace,
    distributor_view,
    selling_program,
    asin,
    COUNT(*) AS row_count
FROM {{ ref('stg_amazon_vendor__sales') }}
GROUP BY 1, 2, 3, 4, 5, 6
HAVING COUNT(*) > 1
