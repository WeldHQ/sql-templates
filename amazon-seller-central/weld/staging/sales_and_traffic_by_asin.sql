-- staging.amazon_seller.sales_and_traffic_by_asin
-- Thin wrapper over raw `sales_and_traffic_report_by_asin_sku`. Casts, renames,
-- de-duplicates. No other logic.
--
-- WHICH OF THE THREE ASIN TABLES. Weld syncs the Sales and Traffic report at three
-- ASIN granularities, and they hold the SAME sales three times over:
--
--   sales_and_traffic_report_by_asin        PARENT granularity  - one row per parent ASIN
--   sales_and_traffic_report_by_asin_child  CHILD granularity   - one row per child ASIN
--   sales_and_traffic_report_by_asin_sku    SKU granularity     - one row per SKU
--
-- All three have identical column lists, including parent_asin, child_asin and sku,
-- which makes them look interchangeable. They are not: UNION or join two of them
-- and you double-count. This model takes the SKU grain because it is the only one
-- that joins to order and settlement data, both of which are keyed on SKU. Roll up
-- to child or parent ASIN in core.
--
-- Traffic caveat: sessions and page views are measured on the CHILD ASIN's detail
-- page, so at SKU grain they are repeated for every SKU sharing that ASIN. Summing
-- sessions across SKUs therefore over-counts. core.amazon_seller.traffic_and_conversion
-- deals with this - do not sum these columns directly.

SELECT
    'seller_1'                                                  AS amazon_seller,
    marketplace,
    date,
    parent_asin,
    child_asin,
    sku,

    units_ordered,
    ordered_product_sales,
    currency,
    total_order_items,

    sessions,
    browser_sessions,
    mobile_app_sessions,
    page_views,
    browser_page_views,
    mobile_app_page_views,

    buy_box_percentage,
    unit_session_percentage,

    -- B2B split. Reported as a SUBSET of the totals above, not in addition to
    -- them: units_ordered already includes units_ordered_b2b. Subtract to get
    -- consumer-only.
    units_ordered_b2b,
    ordered_product_sales_b2b,
    total_order_items_b2b,
    sessions_b2b,
    page_views_b2b
FROM (
    SELECT
        UPPER(NULLIF(TRIM(CAST(marketplace_id AS STRING)), ''))     AS marketplace,

        -- start_date and end_date are equal for a DAY-granularity report, which is
        -- what Weld requests. If you switch the stream to WEEK or MONTH they are a
        -- range, and this collapse to a single date silently mislabels the period -
        -- keep both columns instead.
        CAST(start_date AS DATE)                                    AS date,

        UPPER(NULLIF(TRIM(CAST(parent_asin AS STRING)), ''))        AS parent_asin,
        UPPER(NULLIF(TRIM(CAST(child_asin AS STRING)), ''))         AS child_asin,
        CAST(sku AS STRING)                                         AS sku,

        CAST(units_ordered AS INT64)                                AS units_ordered,
        CAST(ordered_product_sales_amount AS NUMERIC)               AS ordered_product_sales,
        UPPER(NULLIF(TRIM(CAST(ordered_product_sales_currency_code AS STRING)), '')) AS currency,
        CAST(total_order_items AS INT64)                            AS total_order_items,

        CAST(sessions AS INT64)                                     AS sessions,
        CAST(browser_sessions AS INT64)                             AS browser_sessions,
        CAST(mobile_app_sessions AS INT64)                          AS mobile_app_sessions,
        CAST(page_views AS INT64)                                   AS page_views,
        CAST(browser_page_views AS INT64)                            AS browser_page_views,
        CAST(mobile_app_page_views AS INT64)                        AS mobile_app_page_views,

        CAST(buy_box_percentage AS NUMERIC)                         AS buy_box_percentage,
        CAST(unit_session_percentage AS NUMERIC)                    AS unit_session_percentage,

        CAST(units_ordered_b_2_b AS INT64)                          AS units_ordered_b2b,
        CAST(ordered_product_sales_b_2_b_amount AS NUMERIC)         AS ordered_product_sales_b2b,
        CAST(total_order_items_b_2_b AS INT64)                      AS total_order_items_b2b,
        CAST(sessions_b_2_b AS INT64)                               AS sessions_b2b,
        CAST(page_views_b_2_b AS INT64)                             AS page_views_b2b,

        ROW_NUMBER() OVER (
            PARTITION BY marketplace_id, CAST(start_date AS DATE), child_asin, sku
            ORDER BY _weld_synced DESC
        ) AS generation_rank
    FROM {{raw.amazon_seller_central.sales_and_traffic_report_by_asin_sku}}
)
WHERE generation_rank = 1
