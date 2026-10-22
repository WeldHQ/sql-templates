# Amazon Seller Central (orders and settlement reports) templates

SQL reports over Weld's Amazon Seller Central connector. BigQuery.

| Model | Report | What it returns |
|---|---|---|
| [`weld/core/monthly_financial_analysis.sql`](weld/core/monthly_financial_analysis.sql) · [dbt](dbt/models/core/core_amazon_mws__monthly_financial_analysis.sql) | Monthly Financial Analysis | Generates a monthly financial analysis for Amazon integration. It calculates the gross revenue, refunds, net revenue, average item price, average promotion discount, average shipping price, and average shipping tax. The analysis is based on data from the settlement report and orders by last updated date report. The results are sorted in descending order by month. |
| [`weld/core/monthly_inventory_report.sql`](weld/core/monthly_inventory_report.sql) · [dbt](dbt/models/core/core_amazon_mws__monthly_inventory_report.sql) | Monthly Inventory Reports | Extracts monthly inventory reports for Amazon integration. It retrieves data from the Amazon Selling API to calculate various metrics such as total items listed, total fulfillable quantity, total damaged items, expired items, total unfulfillable quantity, items in transit, and items receiving. The results are ordered by month in descending order. |
| [`weld/core/monthly_order_update_tracking_report.sql`](weld/core/monthly_order_update_tracking_report.sql) · [dbt](dbt/models/core/core_amazon_mws__monthly_order_update_tracking_report.sql) | Monthly Order Update Tracking Report | Extracts a monthly order update tracking report for Amazon integration. It retrieves data from the "orders_by_last_updated_date_report" table and calculates various metrics such as total orders updated, total updates, average price updated, status breakdown, and channel breakdown. The results are sorted by month, status count, and channel count in descending order. |
| [`weld/core/monthly_returns_analysis.sql`](weld/core/monthly_returns_analysis.sql) · [dbt](dbt/models/core/core_amazon_mws__monthly_returns_analysis.sql) | Monthly Returns Analysis | Extracts a monthly returns analysis for Amazon integration. It calculates various metrics such as total returns, total refunded amount, in-policy returns, out-of-policy returns, prime returns, and non-prime returns. Additionally, it provides information on return reasons and their respective counts. The results are sorted by month and reason count in descending order. |
| [`weld/core/monthly_sales_performance_report.sql`](weld/core/monthly_sales_performance_report.sql) · [dbt](dbt/models/core/core_amazon_mws__monthly_sales_performance_report.sql) | Monthly Sales Performance Reports | Extracts monthly sales performance reports for Amazon integration. It calculates the total sales amount, number of orders, and total items sold for each month. Additionally, it calculates the average order value by dividing the total sales amount by the number of orders. The results are ordered in descending order by month. |
| [`weld/core/monthly_shipping_and_delivery_report.sql`](weld/core/monthly_shipping_and_delivery_report.sql) · [dbt](dbt/models/core/core_amazon_mws__monthly_shipping_and_delivery_report.sql) | Monthly Shipping and Delivery Reports | Generates a monthly shipping and delivery report for Amazon integration. It calculates various metrics such as the number of orders, total items shipped and unshipped, average days to ship, and the count of premium and regular orders. It also includes information on different shipping service levels and the number of orders for each level. The final result is sorted by month and shipping service level. |

## Where these come from

These are the templates from the weld.app template library, moved here
unchanged apart from the notes below. Each one was published as a single query
rather than a layered model set, so:

- Queries that hold report logic sit in `weld/core/`, each with a `SELECT *`
  passthrough in `weld/analytics/` for dashboards to bind to.
- Most queries read the raw tables directly, so there is no staging layer of
  cast-and-rename wrappers like the one in [`shopify/`](../shopify/).
- None of them has been reconciled against the source system. Treat every model
  as a starting point and check the output before relying on it.
- `dbt/` holds the same SQL with `{{ source() }}` / `{{ ref() }}` refs. No dbt
  tests ship with these models.

## Changes from the website version

Two refs pointed at models that no template supplies:
`{{staging.amazon_selling.orders_by_last_updated_date_report}}` and a bare
`{{returns_by_return_date_report}}`. Both now read the raw tables the templates
list as their inputs, under `raw.amazon_selling_api_oauth`.

For sales, product, settlement, profitability and inventory models that
reconcile to Seller Central, use [`amazon-seller-central/`](../amazon-seller-central/).
These monthly summaries are the older, simpler set.

## Required tables

| Model | Raw tables |
|---|---|
| `core/monthly_financial_analysis` | `amazon_selling_api_oauth.orders_by_last_updated_date_report`, `amazon_selling_api_oauth.settlement_report` |
| `core/monthly_inventory_report` | `amazon_selling_api_oauth.fba_inventory_summary` |
| `core/monthly_order_update_tracking_report` | `amazon_selling_api_oauth.orders_by_last_updated_date_report` |
| `core/monthly_returns_analysis` | `amazon_selling_api_oauth.returns_by_return_date_report` |
| `core/monthly_sales_performance_report` | `amazon_selling_api_oauth.orders` |
| `core/monthly_shipping_and_delivery_report` | `amazon_selling_api_oauth.orders` |

## Models

### Monthly Financial Analysis

`weld/core/monthly_financial_analysis.sql`

The Monthly Financial Analysis SQL template is designed to provide insights into the
financial performance of an Amazon integration. This SQL code calculates various
metrics related to revenue, refunds, item prices, promotion discounts, shipping
prices, and shipping taxes on a monthly basis.

### Monthly Inventory Reports

`weld/core/monthly_inventory_report.sql`

The Monthly Inventory Reports SQL template is designed to generate monthly inventory
reports for Amazon integration. This SQL model retrieves data from the Amazon
Selling API using OAuth authentication. The SQL code calculates various inventory
metrics for each month, including the total quantity of items listed, total
fulfillable quantity, total damaged items, expired items, total unfulfillable
quantity, items in transit, and items receiving.

### Monthly Order Update Tracking Report

`weld/core/monthly_order_update_tracking_report.sql`

The Monthly Order Update Tracking Report SQL template is designed to provide
insights into the monthly order updates for Amazon integration. It retrieves data
from the "orders_by_last_updated_date_report" table in the staging.amazon_selling
schema.

### Monthly Returns Analysis

`weld/core/monthly_returns_analysis.sql`

The Monthly Returns Analysis SQL template is designed to analyze monthly returns
data from the Amazon integration. It calculates various metrics such as total
returns, total refunded amount, in-policy returns, out-of-policy returns, prime
returns, and non-prime returns.

### Monthly Sales Performance Reports

`weld/core/monthly_sales_performance_report.sql`

The Monthly Sales Performance Reports SQL template is designed to analyze sales data
from Amazon. It calculates various metrics such as total sales amount, number of
orders, total items sold, and average order value on a monthly basis. The template
utilizes the Amazon Selling API to retrieve order data and aggregates it by month.

### Monthly Shipping and Delivery Reports

`weld/core/monthly_shipping_and_delivery_report.sql`

The Monthly Shipping and Delivery Reports SQL template is designed to provide
insights into the shipping performance and service levels of Amazon orders on a
monthly basis. By integrating with the Amazon Selling API, this SQL code retrieves
data such as the number of orders, total items shipped and unshipped, average days
to ship, premium and regular orders, and the service level of each order.

## Known issues

Found while moving the templates here. The SQL is kept as published; fix these
before running the affected models.

- `core/monthly_order_update_tracking_report`: the status and channel breakdowns are both joined on month only, so the output is a status × channel cross product with the monthly totals repeated on every row (likely).
