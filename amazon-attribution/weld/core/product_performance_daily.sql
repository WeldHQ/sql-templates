-- core.amazon_attribution.product_performance_daily
-- Daily Amazon Attribution results per product: which ASINs your off-Amazon traffic
-- sold, how much of it was brand halo, and how many buyers were new to the brand.
--
-- Grain: date_day x profile_id x advertiser x campaign_id x ad_group_id x asin x
-- product_conversion_type. Currency: the profile's.
-- Depends on: staging.amazon_attribution.product_performance, .profile
--
-- The raw products report is keyed on product category, subcategory and name,
-- not on ASIN. This model groups on ASIN and sums, so two rows that share an ASIN
-- collapse into one. Amazon keeps 90 days of this report.

SELECT
    p.date_day,
    p.profile_id,
    pr.profile_name,
    pr.currency,
    p.advertiser_name,
    p.campaign_id,
    p.ad_group_id,
    p.asin,
    p.product_conversion_type,
    ANY_VALUE(p.product_name)        AS product_name,
    ANY_VALUE(p.brand_name)          AS brand_name,
    ANY_VALUE(p.product_category)    AS product_category,
    ANY_VALUE(p.product_subcategory) AS product_subcategory,
    ANY_VALUE(p.marketplace)         AS marketplace,

    SUM(p.detail_page_views)                    AS detail_page_views,
    SUM(p.add_to_carts)                         AS add_to_carts,
    SUM(p.purchases)                            AS purchases,
    SUM(p.units_sold)                           AS units_sold,
    SUM(p.sales)                                AS sales,
    SUM(p.new_to_brand_purchases)               AS new_to_brand_purchases,
    SUM(p.new_to_brand_units_sold)              AS new_to_brand_units_sold,
    SUM(p.new_to_brand_sales)                   AS new_to_brand_sales,
    SUM(p.brand_halo_detail_page_views)         AS brand_halo_detail_page_views,
    SUM(p.brand_halo_add_to_carts)              AS brand_halo_add_to_carts,
    SUM(p.brand_halo_purchases)                 AS brand_halo_purchases,
    SUM(p.brand_halo_units_sold)                AS brand_halo_units_sold,
    SUM(p.brand_halo_sales)                     AS brand_halo_sales,
    SUM(p.brand_halo_new_to_brand_purchases)    AS brand_halo_new_to_brand_purchases,
    SUM(p.brand_halo_new_to_brand_units_sold)   AS brand_halo_new_to_brand_units_sold,
    SUM(p.brand_halo_new_to_brand_sales)        AS brand_halo_new_to_brand_sales,

    SAFE_DIVIDE(SUM(p.new_to_brand_sales), SUM(p.sales)) AS new_to_brand_sales_share
FROM {{staging.amazon_attribution.product_performance}} p
-- profile is one row per profile_id after staging, so this join cannot fan out.
LEFT JOIN {{staging.amazon_attribution.profile}} pr
    ON pr.profile_id = p.profile_id
GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9
