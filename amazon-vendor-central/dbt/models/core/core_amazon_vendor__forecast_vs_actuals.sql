-- core_amazon_vendor__forecast_vs_actuals - Amazon's demand forecast against what actually
-- shipped, per ASIN per forecast window.
--
-- Grain: forecast window x vendor x marketplace x ASIN.
-- Depends on: stg_amazon_vendor__forecast, .sales
--
-- WHY BUILD THIS AT ALL. Amazon's forecast drives Amazon's purchase orders. If the
-- forecast for an ASIN is 40% above what has ever shipped, POs are coming that will
-- leave Amazon overstocked - and overstock becomes your markdown request. If it is
-- well below, Amazon will under-order and you will lose sales you could have made.
-- Either way you find out months later, from the consequence rather than the cause.
--
-- This model puts the forecast next to the outcome so you can see the error while it
-- still matters, and take a specific number into a Vendor Manager conversation.
--
-- FORWARD-LOOKING WINDOWS HAVE NO ACTUALS YET, and that is the useful half. Rows
-- where forecast_status = 'FORECAST' are what Amazon expects next; 'REALISED' rows
-- are windows that have fully elapsed and can be scored. 'IN_PROGRESS' is partially
-- elapsed - the actuals are real but incomplete, so do NOT read the error columns on
-- those rows. They are NULL for exactly that reason.
--
-- ONE LIMITATION, AND IT IS STRUCTURAL. Amazon retains only the current forecast, so
-- a realised window is scored against whatever forecast was live when you last
-- synced - which, for a window already in the past, may have been revised toward the
-- outcome. Measuring true forecast accuracy needs the forecast AS IT STOOD before the
-- window opened, which means retaining generations: enable Weld history tables on the
-- vendor_forecasting_report stream and read the history table here instead. Until
-- then, treat these errors as indicative, not as a forecast-accuracy KPI.

{{ config(materialized='table') }}

WITH actuals AS (
    SELECT
        f.amazon_vendor,
        f.marketplace,
        f.asin,
        f.forecast_start_date,
        f.forecast_end_date,
        SUM(s.shipped_units)  AS actual_shipped_units,
        SUM(s.ordered_units)  AS actual_ordered_units,
        COUNT(DISTINCT s.date) AS days_with_sales
    FROM {{ ref('stg_amazon_vendor__forecast') }} f
    -- Range join: a forecast window is a period, and sales are daily. MANUFACTURING
    -- and RETAIL only - the forecast is not split by view or program, so joining all
    -- four variants would multiply the actuals against a single forecast.
    LEFT JOIN {{ ref('stg_amazon_vendor__sales') }} s
           ON  s.amazon_vendor    = f.amazon_vendor
           AND s.marketplace      = f.marketplace
           AND s.asin             = f.asin
           AND s.date BETWEEN f.forecast_start_date AND f.forecast_end_date
           AND s.distributor_view = 'MANUFACTURING'
           AND s.selling_program  = 'RETAIL'
    GROUP BY 1, 2, 3, 4, 5
)

SELECT
    f.amazon_vendor,
    f.marketplace,
    f.asin,
    f.forecast_generation_date,
    f.forecast_start_date,
    f.forecast_end_date,
    f.forecast_window_days,

    f.mean_forecast_units,
    f.p70_forecast_units,
    f.p80_forecast_units,
    f.p90_forecast_units,

    -- How uncertain Amazon is. A wide mean-to-p90 spread on a high-volume ASIN is
    -- where safety stock belongs; a narrow one means Amazon is confident and a miss
    -- will be treated as your supply failure.
    ROUND(SAFE_DIVIDE(f.p90_forecast_units - f.mean_forecast_units,
                      NULLIF(f.mean_forecast_units, 0)), 4) AS forecast_uncertainty_ratio,

    CASE
        WHEN f.forecast_start_date > CURRENT_DATE()  THEN 'FORECAST'
        WHEN f.forecast_end_date   < CURRENT_DATE()  THEN 'REALISED'
        ELSE 'IN_PROGRESS'
    END                                             AS forecast_status,

    a.actual_shipped_units,
    a.actual_ordered_units,
    a.days_with_sales,

    -- Error columns, populated only for fully elapsed windows. A partially elapsed
    -- window would show a large negative error that means nothing except that the
    -- period is not over - which is why these are deliberately NULL there.
    CASE WHEN f.forecast_end_date < CURRENT_DATE()
         THEN COALESCE(a.actual_shipped_units, 0) - f.mean_forecast_units END AS forecast_error_units,

    CASE WHEN f.forecast_end_date < CURRENT_DATE()
         THEN ROUND(SAFE_DIVIDE(COALESCE(a.actual_shipped_units, 0) - f.mean_forecast_units,
                                NULLIF(f.mean_forecast_units, 0)), 4) END     AS forecast_error_rate,

    -- Which confidence band the outcome actually landed in. If most ASINs realise
    -- below p70, Amazon is systematically over-forecasting your catalogue and
    -- over-ordering - that is the finding worth escalating, and it needs a population,
    -- not one ASIN.
    CASE
        WHEN f.forecast_end_date >= CURRENT_DATE()                       THEN NULL
        WHEN COALESCE(a.actual_shipped_units, 0) > f.p90_forecast_units  THEN 'ABOVE_P90'
        WHEN COALESCE(a.actual_shipped_units, 0) > f.p80_forecast_units  THEN 'P80_TO_P90'
        WHEN COALESCE(a.actual_shipped_units, 0) > f.p70_forecast_units  THEN 'P70_TO_P80'
        WHEN COALESCE(a.actual_shipped_units, 0) > f.mean_forecast_units THEN 'MEAN_TO_P70'
        ELSE 'BELOW_MEAN'
    END                                             AS realised_band
FROM {{ ref('stg_amazon_vendor__forecast') }} f
LEFT JOIN actuals a
       ON  a.amazon_vendor       = f.amazon_vendor
       AND a.marketplace         = f.marketplace
       AND a.asin                = f.asin
       AND a.forecast_start_date = f.forecast_start_date
       AND a.forecast_end_date   = f.forecast_end_date
