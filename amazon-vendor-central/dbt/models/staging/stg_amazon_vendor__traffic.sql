-- stg_amazon_vendor__traffic
-- Thin wrapper over raw `vendor_traffic_report`. Casts, renames, de-duplicates.
-- No other logic.
--
-- Glance views are Vendor Central's only traffic metric: the number of times a
-- customer viewed the product detail page. There is no session count, no bounce
-- rate, no funnel - one number per ASIN per day.
--
-- It is still the denominator of the most useful vendor metric there is. Conversion
-- as ordered_units / glance_views tells you whether a flat week was a demand problem
-- or a traffic problem, and those have completely different remedies.
--
-- NOT COMPARABLE TO THE VENDOR CENTRAL DASHBOARD's glance views if you are reading
-- the real-time report - Amazon uses a different counting system there, and says so.
-- This daily report is the one that matches.

SELECT
    'vendor_1'                                                  AS amazon_vendor,
    marketplace,
    date,
    asin,
    glance_views
FROM (
    SELECT
        UPPER(NULLIF(TRIM(CAST(marketplace_id AS STRING)), ''))     AS marketplace,
        CAST(start_date AS DATE)                                    AS date,
        UPPER(NULLIF(TRIM(CAST(asin AS STRING)), ''))               AS asin,
        CAST(glance_views AS INT64)                                 AS glance_views,
        ROW_NUMBER() OVER (
            PARTITION BY marketplace_id, CAST(start_date AS DATE), asin
            ORDER BY _weld_synced DESC
        ) AS generation_rank
    FROM {{ source('amazon_vendor_central', 'vendor_traffic_report') }}
)
WHERE generation_rank = 1
