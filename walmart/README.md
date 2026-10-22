# Walmart Marketplace templates

Rebuilds Walmart Marketplace sales reporting in your warehouse from the Orders
API, and turns Walmart's settlement reconciliation file into a ledger that ties to
each deposit. BigQuery.

Weld connector: **Walmart**
([docs](https://weld.app/docs/applications/walmart)).

| Model | Answers | Grain |
|---|---|---|
| [`weld/core/sales_over_time.sql`](weld/core/sales_over_time.sql) · [dbt](dbt/models/core/core_walmart__sales_over_time.sql) | Sales equation per order day, with shipping and tax | order day × seller × currency × ship node type |
| [`weld/core/product_sales_over_time.sql`](weld/core/product_sales_over_time.sql) · [dbt](dbt/models/core/core_walmart__product_sales_over_time.sql) | The same by SKU, reconciling to the above | order day × seller × currency × ship node type × SKU |
| [`weld/core/settlement_ledger.sql`](weld/core/settlement_ledger.sql) · [dbt](dbt/models/core/core_walmart__settlement_ledger.sql) | What Walmart paid you, itemised, tying to each deposit | settlement date × seller × posted date × purchase order × line × SKU × transaction type |

## Read this first

- **Nothing here has been run against a warehouse.** The models parse, every
  reference resolves, and every column was checked against the connector's
  schema, but no output has been compared with a real seller account. Reconcile a
  month against Seller Center (Payments → reconciliation report, and the order
  export) before relying on it.
- **Two kinds of date.** `sales_over_time` is an order-date view: Walmart's Orders
  API records what was cancelled or refunded on a line but not when, so both are
  attributed back to the day the order was placed and recent days keep moving.
  `settlement_ledger` dates everything by when the money moved, including refunds.
  Use the first for demand, the second for cash.
- **Order history starts at your first sync.** Walmart's Orders API returns orders
  created in the last 180 days only. The connector keeps everything it has synced,
  so history builds up from the day you connect, but it cannot backfill further,
  and a refund issued more than 180 days after its order is not picked up. The
  settlement file has no such limit.
- **Set the timezone** in [`weld/staging/seller.sql`](weld/staging/seller.sql). It
  defaults to `UTC`.

## Layers

```
raw.walmart.*                 ELT output, untouched
  ↓
weld/staging/*.sql            7 thin wrappers: cast, rename, de-duplicate, fix signs
  ↓
weld/core/*.sql               the reports, all the business logic lives here
  ↓
weld/analytics/*.sql          BI-facing contracts, deliberately thin
```

**Staging** casts, renames, keeps the latest version of each row, makes refunds
negative and classifies the settlement file once. It also leaves out customer
names, emails, phone numbers and street addresses.

**Core** is where the sales equation and the ledger live. This is the layer worth
reviewing.

**Analytics** is `SELECT *` over core by design. Dashboards bind to
`analytics.walmart.*`, so core can change without breaking them.

`dbt/` holds the same models with dbt refs, generated from the Weld versions; see
[dbt/README.md](dbt/README.md). With
[GitHub Sync](https://weld.app/docs/transformations/github-sync), Weld references
map to folder paths, so `{{staging.walmart.order}}` expects the model in a
`staging > walmart` folder.

## Required tables

| Model | Raw tables |
|---|---|
| sales over time | `order`, `order_line`, `order_line_charge`, `order_line_status`, `order_line_refund_charge` |
| product sales over time | the same |
| settlement ledger | `recon_report` |

Plus `weld/staging/seller.sql`, a one-row settings model with no raw source.

## What sales_over_time returns

```
net_sales   = gross_sales + cancellations + refunds
total_sales = net_sales + shipping + other_charges + taxes
```

- `gross_sales`: the PRODUCT charge on every order line. Walmart's charge is
  already the price the customer was offered; there is no separate discount line.
- `cancellations`: the cancelled share of each line's product charge, from the
  line's CANCELLED status quantity.
- `refunds`: refunded PRODUCT charges. A line cancelled in full has its refund
  records ignored, so it is not reversed twice.
- `shipping`, `other_charges`, `taxes`: the matching charges, reduced the same way.
- `orders`: purchase orders placed. `units_ordered`, `units_cancelled`, and
  `units` (ordered minus cancelled). Refunds do not reduce `units`: the refund
  records carry money, not quantity.

## What settlement_ledger returns

Every line of every reconciliation file except the PaymentSummary line, with
Walmart's own signs: `product_sales`, `product_refunds`, `shipping`, `commission`,
`fees_and_reimbursements`, `tax_collected`, `tax_withheld`, `other_amount`,
`unclassified_amount` and `net_payable` (a plain sum). Summed over a settlement
date, `net_payable` should equal the file's `total_payable`, the amount
deposited.

## Schema notes

- **Two tax shapes on charges.** Walmart's documentation puts tax under
  `tax.taxAmount`; live responses nest it under `taxAndOtherFees`. The connector
  syncs both (`tax_tax_amount_amount` and
  `tax_and_other_fees_tax_and_other_fees_amount_amount`), and staging uses
  whichever is populated.
- **Line children are keyed by position.** `order_line_charge`,
  `order_line_status` and `order_line_refund_charge` have no natural key and are
  keyed on `index` within the line.
- **The recon file is keyed by row.** `transaction_key` is blank on the summary
  line, so rows are keyed by settlement date and row number. Order columns lose
  their `#`: `Purchase Order #` lands as `purchase_order`.
- **The payment statement is a snapshot.** `payment_statement_report` holds only
  the current cycle and appends one row per sync, so it is not used for history;
  the reconciliation file is.
- The ERD and the connector's own schema agree on every column used here.

## Notes

- **Refund sign.** Refund charges are forced negative in staging, whichever sign
  Walmart sent, so they reduce sales by addition. The settlement file is never
  re-signed.
- **Settlement categories key off `amount_type`**, matched loosely (commission,
  withheld, tax, product price, shipping, fee or reimbursement) because Walmart's
  wording varies. Watch `other_amount` and `unclassified_amount` after any change
  on Walmart's side.
- **Fees are dated by settlement, not by order.** Compare commission and fee rates
  per purchase order or over a long window.
- **Multi-account ready.** Every staging model emits a `walmart_seller` label, part
  of every join key and grain. To add an account, `UNION ALL` a second block in
  each staging model with a different label, and add a row to `seller.sql`.

## Walmart documentation

- [Walmart Marketplace developer docs](https://developer.walmart.com/us-marketplace/docs) (Orders, Returns and Reports sections)
- [Reconciliation report](https://developer.walmart.com/us-marketplace/docs/generate-a-reconciliation-report)
- [Recon report JSON fields](https://developer.walmart.com/us-marketplace/docs/recon-report-json)
