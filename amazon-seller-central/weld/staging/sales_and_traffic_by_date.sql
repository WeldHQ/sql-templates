-- staging.amazon_seller.sales_and_traffic_by_date
-- Thin wrapper over raw `sales_and_traffic_report_by_date`. Casts, renames,
-- de-duplicates. No other logic.
--
-- WHY THE DE-DUPLICATION. This report is re-generated every sync and Amazon
-- restates recent days for up to ~72 hours as cancellations and returns settle.
-- Weld appends each generation, so a single date legitimately appears several
-- times with different numbers. Summing the raw table inflates every recent day by
-- however many times it has been re-fetched - the single most common cause of
-- "our Amazon revenue is 3x too high".
--
-- Latest generation wins, per date per marketplace.

SELECT
    'seller_1'                                                  AS amazon_seller,
    marketplace,
    date,

    ordered_product_sales,
    ordered_product_sales_currency_code                         AS currency,
    units_ordered,
    total_order_items,
    average_selling_price,
    average_units_per_order_item,

    shipped_product_sales,
    units_shipped,
    orders_shipped,

    units_refunded,
    refund_rate,
    claims_granted,
    claims_amount,

    browser_page_views,
    mobile_app_page_views,
    page_views,
    browser_sessions,
    mobile_app_sessions,
    sessions,

    buy_box_percentage,
    order_item_session_percentage,
    unit_session_percentage,
    average_offer_count,
    average_parent_items,

    feedback_received,
    negative_feedback_received,
    received_negative_feedback_rate
FROM (
    SELECT
        UPPER(NULLIF(TRIM(CAST(marketplace_id AS STRING)), ''))     AS marketplace,
        CAST(date AS DATE)                                          AS date,

        CAST(ordered_product_sales_amount AS NUMERIC)               AS ordered_product_sales,
        UPPER(NULLIF(TRIM(CAST(ordered_product_sales_currency_code AS STRING)), '')) AS ordered_product_sales_currency_code,
        CAST(units_ordered AS INT64)                                AS units_ordered,
        CAST(total_order_items AS INT64)                            AS total_order_items,
        CAST(average_selling_price_amount AS NUMERIC)               AS average_selling_price,
        CAST(average_units_per_order_item AS NUMERIC)               AS average_units_per_order_item,

        CAST(shipped_product_sales_amount AS NUMERIC)               AS shipped_product_sales,
        CAST(units_shipped AS INT64)                                AS units_shipped,
        CAST(orders_shipped AS INT64)                               AS orders_shipped,

        CAST(units_refunded AS INT64)                               AS units_refunded,
        CAST(refund_rate AS NUMERIC)                                AS refund_rate,
        CAST(claims_granted AS INT64)                               AS claims_granted,
        CAST(claims_amount_amount AS NUMERIC)                       AS claims_amount,

        CAST(browser_page_views AS INT64)                           AS browser_page_views,
        CAST(mobile_app_page_views AS INT64)                        AS mobile_app_page_views,
        CAST(page_views AS INT64)                                   AS page_views,
        CAST(browser_sessions AS INT64)                             AS browser_sessions,
        CAST(mobile_app_sessions AS INT64)                          AS mobile_app_sessions,
        CAST(sessions AS INT64)                                     AS sessions,

        CAST(buy_box_percentage AS NUMERIC)                         AS buy_box_percentage,
        CAST(order_item_session_percentage AS NUMERIC)              AS order_item_session_percentage,
        CAST(unit_session_percentage AS NUMERIC)                    AS unit_session_percentage,
        CAST(average_offer_count AS INT64)                          AS average_offer_count,
        CAST(average_parent_items AS INT64)                         AS average_parent_items,

        CAST(feedback_received AS INT64)                            AS feedback_received,
        CAST(negative_feedback_received AS INT64)                   AS negative_feedback_received,
        CAST(received_negative_feedback_rate AS NUMERIC)            AS received_negative_feedback_rate,

        ROW_NUMBER() OVER (
            PARTITION BY marketplace_id, CAST(date AS DATE)
            ORDER BY _weld_synced DESC
        ) AS generation_rank
    FROM {{raw.amazon_seller_central.sales_and_traffic_report_by_date}}
)
WHERE generation_rank = 1
