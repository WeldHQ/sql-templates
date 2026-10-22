-- staging.unleashed.sales_order
-- Thin wrapper over raw `sales_order`. One row per sales order, latest version.
--
-- order_status is Unleashed's: Parked, Placed, Backordered, Completed or Deleted.
-- Deleted orders are synced as rows in Deleted status, so they are kept here and
-- filtered in core. Amounts prefixed bc_ are in the company's base currency;
-- the others are in the order currency.

SELECT
    CAST(guid AS STRING)                            AS sales_order_id,
    CAST(order_number AS STRING)                    AS order_number,
    CAST(order_status AS STRING)                    AS order_status,
    CAST(custom_order_status AS STRING)             AS custom_order_status,
    CAST(customer_guid AS STRING)                   AS customer_id,
    CAST(customer_customer_code AS STRING)          AS customer_code,
    CAST(customer_customer_name AS STRING)          AS customer_name,
    CAST(warehouse_guid AS STRING)                  AS warehouse_id,
    CAST(warehouse_warehouse_code AS STRING)        AS warehouse_code,
    CAST(warehouse_warehouse_name AS STRING)        AS warehouse_name,
    CAST(sales_person_full_name AS STRING)          AS salesperson_name,
    CAST(sales_order_group AS STRING)               AS sales_order_group,
    UPPER(CAST(currency_currency_code AS STRING))   AS currency,
    CAST(exchange_rate AS FLOAT64)                  AS exchange_rate,
    CAST(sub_total AS FLOAT64)                      AS sub_total,
    CAST(total AS FLOAT64)                          AS total,
    CAST(bc_sub_total AS FLOAT64)                   AS bc_sub_total,
    CAST(bc_total AS FLOAT64)                       AS bc_total,
    DATE(CAST(order_date AS TIMESTAMP))             AS order_date,
    DATE(CAST(required_date AS TIMESTAMP))          AS required_date,
    DATE(CAST(completed_date AS TIMESTAMP))         AS completed_date,
    CAST(last_modified_on AS TIMESTAMP)             AS last_modified_on
FROM {{raw.unleashed.sales_order}}
WHERE guid IS NOT NULL
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY CAST(guid AS STRING)
    ORDER BY CAST(last_modified_on AS TIMESTAMP) DESC, _weld_synced DESC
) = 1
