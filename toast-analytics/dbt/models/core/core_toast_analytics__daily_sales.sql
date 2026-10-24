-- core_toast_analytics__daily_sales
-- Toast's daily sales KPIs per restaurant: orders, guests, gross and net sales,
-- discounts, refunds, voids, average order value and sales per labor hour.
-- Grain: business date x restaurant.
--
-- The amounts are Toast's own, from its reporting API, so they match the Toast web
-- reports by construction. The ratios are recomputed from the sums on each row
-- rather than taken from Toast, so they re-aggregate correctly: to roll up, sum the
-- numerators and denominators and divide again.
--
-- The labor columns here cover hourly jobs only, as Toast reports them in this
-- endpoint. core.toast_analytics.labor_by_job has all jobs.

SELECT
    business_date,
    restaurant_id,
    restaurant_name,
    orders,
    closed_orders,
    voided_orders,
    discounted_orders,
    guests,
    gross_sales,
    discounts,
    net_sales,
    refunds,
    voided_amount,
    SAFE_DIVIDE(net_sales, orders)                  AS avg_order_value,
    SAFE_DIVIDE(net_sales, guests)                  AS net_sales_per_guest,
    hourly_labor_hours,
    hourly_labor_cost,
    SAFE_DIVIDE(net_sales, hourly_labor_hours)      AS net_sales_per_hourly_labor_hour,
    SAFE_DIVIDE(hourly_labor_cost, net_sales)       AS hourly_labor_pct_of_net_sales
FROM {{ ref('stg_toast_analytics__aggregated_sales') }}
