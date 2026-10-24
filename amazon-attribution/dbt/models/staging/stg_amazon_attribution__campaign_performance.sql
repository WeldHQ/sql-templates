-- stg_amazon_attribution__campaign_performance
-- Thin wrapper over raw `performance_report_by_campaign`, the Amazon Attribution
-- performance report grouped by campaign. Casts, renames, de-duplicates.
--
-- Grain: profile x advertiser name x campaign x date.
--
-- Same metrics as the creative report, plus the Brand Referral Bonus Amazon credits
-- for sales it attributes to your off-Amazon traffic. Sales and bonus are in the
-- profile's currency; all metrics use the 14 day attribution window.

SELECT * EXCEPT (row_rank)
FROM (
    SELECT
        CAST(profile_id AS STRING)                    AS profile_id,
        CAST(advertiser_name AS STRING)               AS advertiser_name,
        CAST(campaign_id AS STRING)                   AS campaign_id,
        DATE(CAST(date AS TIMESTAMP))                 AS date_day,
        CAST(COALESCE(click_throughs, 0) AS INT64)    AS click_throughs,
        CAST(COALESCE(attributed_detail_page_views_clicks_14_d, 0) AS NUMERIC)       AS detail_page_views,
        CAST(COALESCE(attributed_add_to_cart_clicks_14_d, 0) AS NUMERIC)             AS add_to_carts,
        CAST(COALESCE(attributed_purchases_14_d, 0) AS NUMERIC)                      AS purchases,
        CAST(COALESCE(units_sold_14_d, 0) AS NUMERIC)                                AS units_sold,
        CAST(COALESCE(attributed_sales_14_d, 0) AS NUMERIC)                          AS sales,
        CAST(COALESCE(attributed_total_detail_page_views_clicks_14_d, 0) AS NUMERIC) AS total_detail_page_views,
        CAST(COALESCE(attributed_total_add_to_cart_clicks_14_d, 0) AS NUMERIC)       AS total_add_to_carts,
        CAST(COALESCE(attributed_total_purchases_14_d, 0) AS NUMERIC)                AS total_purchases,
        CAST(COALESCE(total_units_sold_14_d, 0) AS NUMERIC)                          AS total_units_sold,
        CAST(COALESCE(total_attributed_sales_14_d, 0) AS NUMERIC)                    AS total_sales,
        CAST(COALESCE(brb_bonus_amount, 0) AS NUMERIC)                               AS brand_referral_bonus,
        ROW_NUMBER() OVER (
            PARTITION BY profile_id, advertiser_name, campaign_id, date
            ORDER BY _weld_synced DESC
        ) AS row_rank
    FROM {{ source('amazon_attribution', 'performance_report_by_campaign') }}
)
WHERE row_rank = 1
