-- core.app_store_connect.sales_and_proceeds
-- Units, customer sales and estimated developer proceeds per app and product, the
-- Sales and Trends view of App Store Connect.
--
-- Grain: one row per day x app SKU x product (Apple ID) x country x product category
-- x customer currency x proceeds currency.
-- Depends on: staging.app_store_connect.sales_report
--
-- CURRENCIES ARE PART OF THE GRAIN. customer_sales is in customer_currency and
-- developer_proceeds in proceeds_currency, and a single country can pay in more than
-- one. Convert before summing across rows; summing as-is adds yen to euros.
--
-- app_sku ties an in-app purchase to its app: Apple fills parent_identifier with the
-- app's SKU on in-app purchase rows and leaves it empty on the app's own rows.
--
-- Units count updates and redownloads too. Filter product_category to
-- 'app_download' for downloads, or to the purchase categories for revenue units.

SELECT
    date_day,
    COALESCE(NULLIF(parent_identifier, ''), sku)        AS app_sku,
    apple_id,
    ANY_VALUE(title)                                    AS title,
    ANY_VALUE(sku)                                      AS sku,
    country_code,
    product_category,
    customer_currency,
    proceeds_currency,

    SUM(units)                                          AS units,
    SUM(IF(units > 0, units, 0))                        AS units_sold,
    SUM(IF(units < 0, -units, 0))                       AS units_refunded,
    SUM(customer_sales)                                 AS customer_sales,
    SUM(developer_proceeds)                             AS developer_proceeds,
    SUM(IF(units < 0, -developer_proceeds, 0))          AS proceeds_refunded
FROM {{staging.app_store_connect.sales_report}}
GROUP BY date_day, app_sku, apple_id, country_code, product_category, customer_currency, proceeds_currency
