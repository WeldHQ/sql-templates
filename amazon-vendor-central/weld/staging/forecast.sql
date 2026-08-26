-- staging.amazon_vendor.forecast
-- Thin wrapper over raw `vendor_forecasting_report`. Casts, renames, keeps the latest
-- forecast generation. No other logic.
--
-- Amazon's own demand forecast for your ASINs: how many units it expects to sell over
-- a future window, at four confidence levels. This is the input to Amazon's own
-- purchase-order generation, which makes it the single most commercially useful table
-- in the connector - it is advance notice of what Amazon is about to order from you.
--
-- CURRENT ONLY, NO HISTORY. Amazon serves the latest forecast and keeps nothing. Once
-- a forecast generation is replaced it is gone, so forecast accuracy - the whole
-- point of having a forecast - can only be measured if you have been retaining
-- generations yourself. Enable Weld history tables on this stream before you need
-- them; you cannot backfill this.
--
-- READING THE FOUR NUMBERS. mean is the expected value. p70/p80/p90 are the units
-- Amazon is 70/80/90% confident of selling, so they rise in that order, and the gap
-- between mean and p90 is how uncertain Amazon is. A wide gap on a high-volume ASIN
-- is where safety stock has to go. Plan capacity against p80 or p90, not the mean -
-- the mean is right half the time by construction.

SELECT
    'vendor_1'                                                  AS amazon_vendor,
    marketplace,
    forecast_generation_date,
    asin,
    forecast_start_date,
    forecast_end_date,
    mean_forecast_units,
    p70_forecast_units,
    p80_forecast_units,
    p90_forecast_units,
    DATE_DIFF(forecast_end_date, forecast_start_date, DAY) + 1  AS forecast_window_days
FROM (
    SELECT
        UPPER(NULLIF(TRIM(CAST(marketplace_id AS STRING)), ''))     AS marketplace,
        CAST(forecast_generation_date AS DATE)                      AS forecast_generation_date,
        UPPER(NULLIF(TRIM(CAST(asin AS STRING)), ''))               AS asin,
        CAST(start_date AS DATE)                                    AS forecast_start_date,
        CAST(end_date AS DATE)                                      AS forecast_end_date,
        CAST(mean_forecast_units AS NUMERIC)                        AS mean_forecast_units,
        CAST(p_70_forecast_units AS NUMERIC)                        AS p70_forecast_units,
        CAST(p_80_forecast_units AS NUMERIC)                        AS p80_forecast_units,
        CAST(p_90_forecast_units AS NUMERIC)                        AS p90_forecast_units,

        -- One row per ASIN per forecast window, from the most recent generation.
        -- Ordering on generation date first, then sync, so an unchanged forecast
        -- re-fetched today does not displace a newer one.
        ROW_NUMBER() OVER (
            PARTITION BY marketplace_id, asin, CAST(start_date AS DATE), CAST(end_date AS DATE)
            ORDER BY CAST(forecast_generation_date AS DATE) DESC, _weld_synced DESC
        ) AS generation_rank
    FROM {{raw.amazon_vendor_central.vendor_forecasting_report}}
)
WHERE generation_rank = 1
