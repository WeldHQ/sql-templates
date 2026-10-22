-- core_woocommerce__customers
-- Recreates WooCommerce Analytics' Customers report: every customer, registered or
-- guest, with orders, spend, average order value and first and last order.
--
-- Grain: store x customer (wc_customer_lookup.customer_id). Customers who have
-- never placed a counted order are kept, with zero orders, as Analytics lists them.
--
-- Built on sales_over_time, so the same status and report date rules apply and a
-- customer's totals add up to the store's.
--   total_spend      Analytics' "Total spend": order totals including tax and
--                    shipping, net of refunds.
--   net_sales        the same before tax and shipping; usually what finance wants.
--   avg_order_value  total_spend / orders, as Analytics computes it. A ratio of
--                    sums, so it stays correct when you re-aggregate.
--
-- Location is the customer's latest billing address, not the address of each
-- order.
--
-- Depends on: core.woocommerce.sales_over_time, staging.woocommerce.customer_lookup

WITH by_customer AS (
    SELECT
        woocommerce_store,
        customer_id,
        ANY_VALUE(currency)                    AS currency,
        SUM(orders)                            AS orders,
        SUM(items_sold)                        AS items_sold,
        SUM(net_sales)                         AS net_sales,
        SUM(total_sales)                       AS total_spend,
        SUM(returns)                           AS returns,
        MIN(IF(row_type = 'SALE', date, NULL)) AS first_order_date,
        MAX(IF(row_type = 'SALE', date, NULL)) AS last_order_date
    FROM {{ ref('core_woocommerce__sales_over_time') }}
    WHERE customer_id IS NOT NULL
    GROUP BY woocommerce_store, customer_id
)

SELECT
    c.woocommerce_store,
    c.customer_id,
    c.user_id,
    c.is_guest,
    c.username,
    c.first_name,
    c.last_name,
    c.email,
    c.country,
    c.state,
    c.city,
    c.postcode,
    DATE(c.date_registered_local)  AS date_registered,
    DATE(c.date_last_active_local) AS date_last_active,
    b.first_order_date,
    b.last_order_date,
    b.currency,
    COALESCE(b.orders, 0)          AS orders,
    COALESCE(b.items_sold, 0)      AS items_sold,
    ROUND(COALESCE(b.net_sales, 0), 2)   AS net_sales,
    ROUND(COALESCE(b.returns, 0), 2)     AS returns,
    ROUND(COALESCE(b.total_spend, 0), 2) AS total_spend,
    ROUND(SAFE_DIVIDE(b.total_spend, NULLIF(b.orders, 0)), 2) AS avg_order_value
FROM {{ ref('stg_woocommerce__customer_lookup') }} c
LEFT JOIN by_customer b USING (woocommerce_store, customer_id)
