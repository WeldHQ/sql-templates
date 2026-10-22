# e-conomic templates

SQL reports over Weld's e-conomic connector. BigQuery.

| Model | Report | What it returns |
|---|---|---|
| [`weld/core/invoice_line_items.sql`](weld/core/invoice_line_items.sql) · [dbt](dbt/models/core/core_economic__invoice_line_items.sql) | Invoice line items | Retrieves invoice line items from the economic integration. It combines data from the "booked_invoices" table and the "products" and "customers" tables to provide information such as the customer name, invoice details, product details, and order by date in descending order. |
| [`weld/core/order_items.sql`](weld/core/order_items.sql) · [dbt](dbt/models/core/core_economic__order_items.sql) | Order items | Retrieves order items from the "economic" integration. It combines data from the "orders" table and the "customers" table, joining them based on the customer ID. The result is sorted in descending order by date. |

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

## Required tables

| Model | Raw tables |
|---|---|
| `core/invoice_line_items` | `economic.booked_invoices`, `economic.customers`, `economic.products` |
| `core/order_items` | `economic.customers`, `economic.orders` |

## Models

### Invoice line items

`weld/core/invoice_line_items.sql`

The SQL template "Invoice line items" is designed to retrieve detailed information
about invoice line items from the Economic integration. This SQL model allows you to
extract data such as the date, invoice line ID, invoice ID, customer ID, invoice
type, currency, quantity, line ID, unit net price, discount percentage, unit cost
price, VAT rate, VAT amount, net amount excluding tax, net amount including tax,
product ID, customer name, and more.

### Order items

`weld/core/order_items.sql`

The SQL template named "Order items" is designed for integration with the economic
system. This SQL model allows you to retrieve detailed information about order
items, including the date, order ID, order line ID, customer ID, invoice type,
currency, line ID, description, unit, quantity, unit net price, discount percentage,
unit cost price, total net amount, margin in base currency, margin percentage, and
departmental distribution.

## Known issues

Found while moving the templates here. The SQL is kept as published; fix these
before running the affected models.

- `core/invoice_line_items` and `core/order_items`: `concat()` is applied to numeric IDs, and BigQuery's CONCAT only accepts strings. Cast them first (likely).
