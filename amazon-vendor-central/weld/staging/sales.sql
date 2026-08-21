-- staging.amazon_vendor.sales
-- Thin wrapper over raw `vendor_sales_report`. Casts, renames, de-duplicates.
-- No other logic.
--
-- THE TABLE THE WHOLE VENDOR MODEL RESTS ON, and it is not shaped like a seller
-- sales report. There are no orders here and never will be: as a vendor you sell to
-- Amazon, Amazon sells to the customer, and Amazon reports aggregates. So the grain
-- is date x ASIN, the numbers are pre-aggregated, and there is nothing to sum up
-- from line items.
--
-- WHY THERE ARE FOUR OF THIS REPORT. Amazon generates Vendor Sales separately for
-- each combination of two dimensions:
--
--   distributorView   MANUFACTURING - ASINs you manufacture, whoever sourced them
--                     SOURCING      - ASINs sourced directly from your vendor group
--   sellingProgram    RETAIL        - amazon.com consumer
--                     BUSINESS      - Amazon Business (B2B)
--
-- Weld lands all of them in this one table, distinguished by the distributor_view
-- and selling_program columns. They OVERLAP: an ASIN you manufacture and also source
-- appears under both views, describing the same units. Summing without filtering
-- double-counts revenue, and it is not a small error - for most vendors it is close
-- to a clean 2x. Every model downstream keeps both columns in the grain so that the
-- choice has to be made explicitly.
--
-- WHICH VIEW TO USE: MANUFACTURING + RETAIL is the default for "how is my brand
-- selling on Amazon". Use SOURCING only when you specifically mean the products
-- Amazon buys from you directly.
--
-- ORDERED vs SHIPPED, and this is the one that surprises people coming from Seller
-- Central: as a vendor your revenue is SHIPPED, not ordered. shipped_cogs is what
-- Amazon pays you (your wholesale price); shipped_revenue is what Amazon charges the
-- customer, which is Amazon's revenue, not yours. ordered_revenue is customer demand
-- and is populated on the MANUFACTURING view only.

SELECT
    'vendor_1'                                  AS amazon_vendor,
    marketplace,
    distributor_view,
    selling_program,
    date,
    asin,

    ordered_units,
    ordered_revenue,
    shipped_units,
    shipped_revenue,
    shipped_cogs,
    customer_returns,
    currency
FROM (
    SELECT
        UPPER(NULLIF(TRIM(CAST(marketplace_id AS STRING)), ''))     AS marketplace,
        UPPER(NULLIF(TRIM(CAST(distributor_view AS STRING)), ''))   AS distributor_view,
        UPPER(NULLIF(TRIM(CAST(selling_program AS STRING)), ''))    AS selling_program,

        -- start_date and end_date are equal on a DAY-period report, which is what
        -- these models assume. If the stream is configured for WEEK or MONTH,
        -- collapsing to start_date silently relabels a period as a day - keep both
        -- columns and change the grain instead.
        CAST(start_date AS DATE)                                    AS date,
        UPPER(NULLIF(TRIM(CAST(asin AS STRING)), ''))               AS asin,

        CAST(ordered_units AS INT64)                                AS ordered_units,
        CAST(ordered_revenue_amount AS NUMERIC)                     AS ordered_revenue,
        CAST(shipped_units AS INT64)                                AS shipped_units,
        CAST(shipped_revenue_amount AS NUMERIC)                     AS shipped_revenue,
        CAST(shipped_cogs_amount AS NUMERIC)                        AS shipped_cogs,

        -- Amazon reports returns as a positive count. Negated here so it composes
        -- with shipped_units by addition, the same convention as everywhere else in
        -- this library.
        -1 * ABS(CAST(customer_returns AS INT64))                   AS customer_returns,

        UPPER(NULLIF(TRIM(CAST(COALESCE(shipped_cogs_currency_code, ordered_revenue_currency_code) AS STRING)), '')) AS currency,

        -- Amazon restates the trailing ~72 hours as returns and adjustments settle,
        -- and Weld appends each generation. Latest generation per key wins; without
        -- this, recent days are counted as many times as they have been re-fetched.
        ROW_NUMBER() OVER (
            PARTITION BY marketplace_id, distributor_view, selling_program,
                         CAST(start_date AS DATE), asin
            ORDER BY _weld_synced DESC
        ) AS generation_rank
    FROM {{raw.amazon_vendor_central.vendor_sales_report}}
)
WHERE generation_rank = 1
