-- staging.amazon_attribution.creative_performance
-- Thin wrapper over raw `performance_report_by_creative`, the Amazon Attribution
-- performance report grouped by creative. Casts, renames, de-duplicates.
--
-- Grain: profile x advertiser name x campaign x ad group x creative x date.
--
-- The report carries no advertiser id, only the name, so the advertiser is keyed on
-- name here and resolved to an id in core. Clicks without a creative arrive with
-- creative_id 'unknown'. All metrics use Amazon's 14 day attribution window;
-- "total" metrics add brand halo (other products of the same brand) to the
-- promoted products. Sales are in the profile's currency.

SELECT * EXCEPT (row_rank)
FROM (
    SELECT
        CAST(profile_id AS STRING)                    AS profile_id,
        CAST(advertiser_name AS STRING)               AS advertiser_name,
        CAST(campaign_id AS STRING)                   AS campaign_id,
        CAST(ad_group_id AS STRING)                   AS ad_group_id,
        CAST(creative_id AS STRING)                   AS creative_id,
        DATE(CAST(date AS TIMESTAMP))                 AS date_day,
        CAST(publisher AS STRING)                     AS publisher,
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
        CAST(COALESCE(kindle_edition_normalized_pages_read_14_d, 0) AS NUMERIC)      AS kenp_pages_read,
        CAST(COALESCE(kindle_edition_normalized_pages_royalties_14_d, 0) AS NUMERIC) AS kenp_royalties,
        ROW_NUMBER() OVER (
            PARTITION BY profile_id, advertiser_name, campaign_id, ad_group_id, creative_id, date
            ORDER BY _weld_synced DESC
        ) AS row_rank
    FROM {{raw.amazon_attribution.performance_report_by_creative}}
)
WHERE row_rank = 1
