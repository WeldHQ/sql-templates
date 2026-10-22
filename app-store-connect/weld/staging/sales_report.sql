-- staging.app_store_connect.sales_report
-- Thin wrapper over raw `sales_report` (Apple's daily Sales and Trends summary
-- report). Casts, renames, multiplies per-unit prices out to row totals,
-- classifies the product type. De-duplicates on the connector's primary key.
--
-- Grain: day x country x app version x device x product type x title x category x
-- subscription flag, as the connector keys it.
--
-- MONEY. customer_price and developer_proceeds are PER UNIT in Apple's file, in two
-- different currencies: what the customer paid in customer_currency, what you earn
-- in currency_of_proceeds. Totals here are units x per-unit amount.
--
-- REFUND SIGNS. Apple writes a refund as negative units, negative customer price and
-- POSITIVE developer proceeds. Multiplying units by customer_price as delivered would
-- turn a refund into positive sales. Both totals therefore use the absolute per-unit
-- amount, so the sign comes from units alone and refunds net out by plain addition.
--
-- Proceeds in this report are estimates. Apple's monthly Financial Reports are what
-- you are paid on.

SELECT
    CAST(date AS DATE)                              AS date_day,
    CAST(apple_identifier AS STRING)                AS apple_id,
    CAST(parent_identifier AS STRING)               AS parent_identifier,
    CAST(sku AS STRING)                             AS sku,
    CAST(title AS STRING)                           AS title,
    CAST(version AS STRING)                         AS app_version,
    CAST(product_type_identifier AS STRING)         AS product_type_identifier,
    -- Apple's product type identifiers, grouped as App Store Connect groups them.
    CASE
        WHEN product_type_identifier IN ('1', '1F', '1T', 'F1', '1E', '1EP', '1EU', '1-B', 'F1-B') THEN 'app_download'
        WHEN product_type_identifier IN ('3', '3F')                                         THEN 'redownload'
        WHEN product_type_identifier IN ('7', '7F', '7T', 'F7')                              THEN 'update'
        WHEN product_type_identifier IN ('IAY', 'IAY-M')                                    THEN 'auto_renewable_subscription'
        WHEN product_type_identifier IN ('IA1', 'IA1-M', 'IA9', 'IA9-M', 'FI1')             THEN 'in_app_purchase'
        WHEN product_type_identifier = 'IA3'                                                THEN 'restored_in_app_purchase'
        ELSE 'other'
    END                                             AS product_category,
    UPPER(CAST(country_code AS STRING))             AS country_code,
    CAST(device AS STRING)                          AS device,
    CAST(category AS STRING)                        AS app_category,
    CAST(subscription AS STRING)                    AS subscription_status,
    CAST(period AS STRING)                          AS subscription_period,
    CAST(promo_code AS STRING)                      AS promo_code,
    CAST(proceeds_reason AS STRING)                 AS proceeds_reason,
    CAST(order_type AS STRING)                      AS order_type,

    CAST(units AS INT64)                            AS units,
    UPPER(CAST(customer_currency AS STRING))        AS customer_currency,
    ABS(CAST(customer_price AS NUMERIC))            AS customer_price_per_unit,
    CAST(units AS INT64) * ABS(CAST(customer_price AS NUMERIC))      AS customer_sales,
    UPPER(CAST(currency_of_proceeds AS STRING))     AS proceeds_currency,
    ABS(CAST(developer_proceeds AS NUMERIC))        AS proceeds_per_unit,
    CAST(units AS INT64) * ABS(CAST(developer_proceeds AS NUMERIC))  AS developer_proceeds
FROM {{raw.app_store_connect.sales_report}}
WHERE TRUE
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY date, country_code, version, device, product_type_identifier, title,
                 category, subscription
    ORDER BY _weld_synced DESC
) = 1
