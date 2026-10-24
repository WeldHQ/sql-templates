-- core.grin.conversions_by_day
-- Affiliate and discount-code sales over time, per campaign: orders, revenue and
-- commission on the day Grin recorded the conversion.
--
-- Grain: day x grin_account x campaign x conversion type x currency.
-- Depends on: staging.grin.campaign_conversion, .campaign
--
-- Currency is in the grain so a store selling in two currencies never sums them.
-- conversion_type is Grin's own label for how the order was attributed, passed
-- through as Grin sends it.
--
-- VOIDS LAND ON THE CONVERSION DAY, not the void day. A refund in March of a
-- January order lowers January. That keeps this model reconciling to
-- campaign_performance; the consequence is that a closed month can still move.
--
-- Conversions without a creator are left out, the same population
-- campaign_performance counts, so the two reconcile.
--
-- TIME ZONE: days are cut in UTC. Change the 'UTC' literal to your reporting zone.
--
-- Spine: each campaign x type x currency gets every day between its first and its
-- last conversion, so a quiet day inside a campaign's selling period is a zero, not
-- a gap.

WITH params AS (
    SELECT 'UTC' AS tz
),

daily AS (
    SELECT
        cv.grin_account,
        cv.campaign_id,
        COALESCE(cv.conversion_type, 'unknown')            AS conversion_type,
        COALESCE(cv.currency, 'unknown')                   AS currency,
        DATE(cv.converted_at, p.tz)                        AS date,
        COUNTIF(NOT cv.is_voided)                          AS conversions,
        COUNTIF(cv.is_voided)                              AS voided_conversions,
        SUM(IF(NOT cv.is_voided, cv.amount, 0))            AS revenue,
        SUM(IF(cv.is_voided, cv.amount, 0))                AS voided_revenue,
        SUM(IF(NOT cv.is_voided, cv.commission_amount, 0)) AS commission,
        COUNT(DISTINCT IF(NOT cv.is_voided, cv.contact_id, NULL)) AS creators_with_sales
    FROM {{staging.grin.campaign_conversion}} cv
    CROSS JOIN params p
    WHERE cv.converted_at IS NOT NULL
      AND cv.contact_id IS NOT NULL
    GROUP BY 1, 2, 3, 4, 5
),

series AS (
    SELECT grin_account, campaign_id, conversion_type, currency,
           MIN(date) AS first_date, MAX(date) AS last_date
    FROM daily
    GROUP BY 1, 2, 3, 4
),

spine AS (
    SELECT s.grin_account, s.campaign_id, s.conversion_type, s.currency, d AS date
    FROM series s,
        UNNEST(GENERATE_DATE_ARRAY(s.first_date, s.last_date, INTERVAL 1 DAY)) AS d
)

SELECT
    sp.date,
    sp.grin_account,
    sp.campaign_id,
    c.campaign_name,
    sp.conversion_type,
    sp.currency,
    COALESCE(dl.conversions, 0)          AS conversions,
    COALESCE(dl.voided_conversions, 0)   AS voided_conversions,
    COALESCE(dl.revenue, 0)              AS revenue,
    COALESCE(dl.voided_revenue, 0)       AS voided_revenue,
    COALESCE(dl.commission, 0)           AS commission,
    -- Distinct per day; do not sum across days.
    COALESCE(dl.creators_with_sales, 0)  AS creators_with_sales
FROM spine sp
LEFT JOIN daily dl
    ON  dl.grin_account    = sp.grin_account
    AND dl.campaign_id     = sp.campaign_id
    AND dl.conversion_type = sp.conversion_type
    AND dl.currency        = sp.currency
    AND dl.date            = sp.date
LEFT JOIN {{staging.grin.campaign}} c
    ON  c.grin_account = sp.grin_account AND c.campaign_id = sp.campaign_id
