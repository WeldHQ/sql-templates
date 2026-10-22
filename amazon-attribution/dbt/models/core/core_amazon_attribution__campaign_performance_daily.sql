-- core_amazon_attribution__campaign_performance_daily
-- Daily campaign results as the Amazon Attribution console shows them: click-throughs,
-- detail page views, add to carts, purchases and sales, promoted and total, with the
-- funnel rates and the Brand Referral Bonus.
--
-- Grain: date_day x profile_id x advertiser x campaign_id. Currency: the profile's.
-- Depends on: staging.amazon_attribution.campaign_performance, .advertiser, .profile
--
-- Built from the campaign report rather than by rolling up creatives: only the
-- campaign and ad group reports carry the Brand Referral Bonus.
-- Rates are ratios of sums at this grain. For a week or a month, re-sum the base
-- columns and divide again rather than averaging the daily rates.

WITH advertiser AS (
    SELECT profile_id, advertiser_name, MIN(advertiser_id) AS advertiser_id
    FROM {{ ref('stg_amazon_attribution__advertiser') }}
    GROUP BY 1, 2
)

SELECT
    c.date_day,
    c.profile_id,
    pr.profile_name,
    pr.currency,
    a.advertiser_id,
    c.advertiser_name,
    c.campaign_id,

    c.click_throughs,
    c.detail_page_views,
    c.add_to_carts,
    c.purchases,
    c.units_sold,
    c.sales,
    c.total_detail_page_views,
    c.total_add_to_carts,
    c.total_purchases,
    c.total_units_sold,
    c.total_sales,
    c.total_sales - c.sales                                     AS brand_halo_sales,
    c.brand_referral_bonus,

    SAFE_DIVIDE(c.total_detail_page_views, c.click_throughs)   AS detail_page_view_rate,
    SAFE_DIVIDE(c.total_add_to_carts, c.click_throughs)        AS add_to_cart_rate,
    SAFE_DIVIDE(c.total_purchases, c.click_throughs)           AS purchase_rate,
    SAFE_DIVIDE(c.total_sales, c.total_purchases)              AS average_order_value
FROM {{ ref('stg_amazon_attribution__campaign_performance') }} c
LEFT JOIN advertiser a
    ON a.profile_id = c.profile_id AND a.advertiser_name = c.advertiser_name
LEFT JOIN {{ ref('stg_amazon_attribution__profile') }} pr
    ON pr.profile_id = c.profile_id
