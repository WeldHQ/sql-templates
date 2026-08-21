-- staging.amazon_seller.sku_cost
-- YOUR COGS. This is the one model in the library you have to write yourself.
--
-- Amazon knows what it charged you in fees. It does not know what your goods cost,
-- so no report can supply it and no template can invent it. Until this model
-- returns real numbers, core.amazon_seller.asin_profitability computes contribution
-- after Amazon's fees - useful, but not margin.
--
-- The contract is three columns: amazon_seller, sku, unit_cost, plus a validity
-- window. Point it at whatever you actually have and keep the shape:
--
--   * A spreadsheet, synced with Weld's Google Sheets connector. Most common, and
--     fine - a maintained sheet beats a perfect model nobody updates.
--   * Your ERP or inventory system, if you have one.
--   * Purchase order receipts, for landed cost including freight and duty.
--
-- THE WINDOW IS THE POINT. valid_from / valid_to make cost point-in-time, so a
-- January order is valued at January's cost rather than at today's. Flat current
-- cost silently restates last year's margin every time a supplier price changes.
-- If you only have current cost, set valid_from to DATE '1900-01-01' and valid_to
-- to NULL and accept that limitation knowingly.
--
-- Overlapping windows for one SKU will fan out the join in asin_profitability and
-- overstate cost. Keep them contiguous and non-overlapping.

SELECT
    'seller_1'                                          AS amazon_seller,
    CAST(sku AS STRING)                                 AS sku,
    CAST(unit_cost AS NUMERIC)                          AS unit_cost,
    UPPER(NULLIF(TRIM(CAST(currency AS STRING)), ''))   AS currency,
    CAST(valid_from AS DATE)                            AS valid_from,
    -- NULL means "still current". The join in asin_profitability treats it as open
    -- ended, so do not backfill it with a far-future date.
    CAST(valid_to AS DATE)                              AS valid_to
FROM {{raw.google_sheets.sku_cost}}
