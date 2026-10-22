-- staging.amazon_attribution.product_performance
-- Thin wrapper over raw `product_report`, the Amazon Attribution products report.
-- Casts, renames, de-duplicates.
--
-- Grain: profile x advertiser name x campaign x ad group x product x date, keyed the
-- way the connector keys it (product category, subcategory and name).
--
-- Promoted metrics are for the products on the campaign; brand halo metrics are for
-- other products of the same brand. New-to-brand counts customers who had not bought
-- the brand on Amazon in the previous 12 months. Sales are in the profile's
-- currency; all metrics use the 14 day attribution window. Amazon keeps 90 days of
-- this report, so history before your first sync cannot be backfilled.

SELECT * EXCEPT (row_rank)
FROM (
    SELECT
        CAST(profile_id AS STRING)            AS profile_id,
        CAST(advertiser_name AS STRING)       AS advertiser_name,
        CAST(campaign_id AS STRING)           AS campaign_id,
        CAST(ad_group_id AS STRING)           AS ad_group_id,
        DATE(CAST(date AS TIMESTAMP))         AS date_day,
        CAST(publisher AS STRING)             AS publisher,
        CAST(marketplace AS STRING)           AS marketplace,
        CAST(product_asin AS STRING)          AS asin,
        CAST(product_name AS STRING)          AS product_name,
        CAST(brand_name AS STRING)            AS brand_name,
        CAST(product_group AS STRING)         AS product_group,
        CAST(product_category AS STRING)      AS product_category,
        CAST(product_subcategory AS STRING)   AS product_subcategory,
        CAST(product_conversion_type AS STRING) AS product_conversion_type,
        CAST(COALESCE(attributed_detail_page_views_clicks_14_d, 0) AS NUMERIC)      AS detail_page_views,
        CAST(COALESCE(attributed_add_to_cart_clicks_14_d, 0) AS NUMERIC)            AS add_to_carts,
        CAST(COALESCE(attributed_purchases_14_d, 0) AS NUMERIC)                     AS purchases,
        CAST(COALESCE(units_sold_14_d, 0) AS NUMERIC)                               AS units_sold,
        CAST(COALESCE(attributed_sales_14_d, 0) AS NUMERIC)                         AS sales,
        CAST(COALESCE(attributed_new_to_brand_purchases_14_d, 0) AS NUMERIC)        AS new_to_brand_purchases,
        CAST(COALESCE(attributed_new_to_brand_units_sold_14_d, 0) AS NUMERIC)       AS new_to_brand_units_sold,
        CAST(COALESCE(attributed_new_to_brand_sales_14_d, 0) AS NUMERIC)            AS new_to_brand_sales,
        CAST(COALESCE(brand_halo_detail_page_views_clicks_14_d, 0) AS NUMERIC)      AS brand_halo_detail_page_views,
        CAST(COALESCE(brand_halo_attributed_add_to_cart_clicks_14_d, 0) AS NUMERIC) AS brand_halo_add_to_carts,
        CAST(COALESCE(brand_halo_attributed_purchases_14_d, 0) AS NUMERIC)          AS brand_halo_purchases,
        CAST(COALESCE(brand_halo_units_sold_14_d, 0) AS NUMERIC)                    AS brand_halo_units_sold,
        CAST(COALESCE(brand_halo_attributed_sales_14_d, 0) AS NUMERIC)              AS brand_halo_sales,
        CAST(COALESCE(brand_halo_new_to_brand_purchases_14_d, 0) AS NUMERIC)        AS brand_halo_new_to_brand_purchases,
        CAST(COALESCE(brand_halo_new_to_brand_units_sold_14_d, 0) AS NUMERIC)       AS brand_halo_new_to_brand_units_sold,
        CAST(COALESCE(brand_halo_new_to_brand_sales_14_d, 0) AS NUMERIC)            AS brand_halo_new_to_brand_sales,
        ROW_NUMBER() OVER (
            PARTITION BY profile_id, advertiser_name, campaign_id, ad_group_id, date,
                         product_category, product_subcategory, product_name
            ORDER BY _weld_synced DESC
        ) AS row_rank
    FROM {{raw.amazon_attribution.product_report}}
)
WHERE row_rank = 1
