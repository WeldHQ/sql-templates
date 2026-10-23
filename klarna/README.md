# Klarna templates

Payout reconciliation, settled sales and Klarna's fees from Weld's Klarna connector.
BigQuery, in each payout's own currency.

| Model | Answers | Grain |
|---|---|---|
| [`weld/core/payout_reconciliation.sql`](weld/core/payout_reconciliation.sql) · [dbt](dbt/models/core/core_klarna__payout_reconciliation.sql) | What each bank deposit from Klarna was made of, and whether the transactions add up to it | account × merchant × payout |
| [`weld/core/daily_settlement_activity.sql`](weld/core/daily_settlement_activity.sql) · [dbt](dbt/models/core/core_klarna__daily_settlement_activity.sql) | Sales vs returns vs fees, per day | day × account × merchant × currency |
| [`weld/core/fees_by_type.sql`](weld/core/fees_by_type.sql) · [dbt](dbt/models/core/core_klarna__fees_by_type.sql) | What Klarna charged, by fee type, and the effective rate on sales | month × account × merchant × currency × type × detailed type |

## Read this first: what this connector can and cannot tell you

The connector reads Klarna's Settlements API: payouts, and the transactions settled
in each payout. That shapes everything below.

**1. This is settled money, not orders.** A sale appears once Klarna has put it in a
payout, typically days after checkout. The last few days of every report are always
incomplete, and nothing here shows authorised but uncaptured orders, open
disputes, or what a customer still owes Klarna. For order-time revenue, use your
shop platform; use these models to explain the deposit.

**2. Amounts are in minor units at the source.** Klarna sends EUR 12.34 as `1234`.
Staging divides every amount by 100 once. Every currency Klarna settles in has two
decimals, so this holds for all of them.

**3. Klarna documents a type for each transaction, not a sign.** The API reference
says what `SALE`, `RETURN`, `FEE`, `HOLDBACK` and the rest are, but not whether
`amount` is negative on a return. Staging therefore derives `signed_amount` from the
type and `ABS(amount)`, which gives the same answer whichever convention an account
returns. Three types have no documented direction (`COMMISSION`, `CORRECTION`,
`REVERSAL_MERCHANT_PROTECTION`): they keep Klarna's raw value, stay out of every net
figure, and are reported in their own columns. If they are material for you, check
one against the payout PDF in the Merchant Portal and add it to the `CASE` in
`staging/transaction.sql`.

**4. Payouts are per currency and per merchant account.** `payment_reference` is
only unique within a merchant, and a merchant selling in several currencies gets one
payout per currency. Every model keeps `currency_code` in the grain. Never sum an
amount column across currencies.

## Layers

```
raw.klarna.*            ELT output, untouched
  ↓
weld/staging/*.sql      2 thin wrappers: minor units, 'unset' to NULL, direction
  ↓
weld/core/*.sql         the reports, all the business logic lives here
  ↓
weld/analytics/*.sql    BI-facing contracts, deliberately thin
```

**Staging** casts, renames, divides by 100, and turns the connector's `'unset'`
placeholder and Klarna's empty strings into NULL, so `COUNT(DISTINCT order_id)` does
not count a placeholder as an order. It also attaches `ledger_direction` and
`signed_amount`, the one classification every core model needs.

**Core** holds the tie-out, the spines and the fee breakdown. This is the layer worth
reviewing.

**Analytics** exists for indirection, not transformation. Bind dashboards and
reverse-ETL syncs to `analytics.klarna.payout_reconciliation` so core stays free to
be renamed or re-grained. All three are `SELECT *`: that is the point, not an
oversight.

With [GitHub Sync](https://weld.app/docs/transformations/github-sync) a push deploys
all of them and Weld resolves the dependency order. Weld references map to folder
paths, so `{{staging.klarna.payout}}` expects the model in a `staging > klarna`
folder. Mirror that structure in your synced repo, or adjust the refs.

## Required tables

| Model | Raw tables |
|---|---|
| payout reconciliation | `payout`, `transaction` |
| daily settlement activity | `transaction` |
| fees by type | `transaction` |

Sync both streams over the same window. The connector reads transactions payout by
payout, so a transaction stream that reaches further back than the payout stream
produces orphans that
[`assert_klarna__transactions_belong_to_a_payout`](dbt/tests/assert_klarna__transactions_belong_to_a_payout.sql)
will list.

## What payout_reconciliation returns

One row per payout. `settlement_amount` is Klarna's figure for the payout itself,
the number to match to the bank line. Next to it is Klarna's own breakdown, the
`totals_` fields: `sale_amount`, `return_amount`, `fee_amount`, `tax_amount`,
`holdback_amount`, `release_amount`, `deposit_amount`, the opening and closing debt
balance and the rest.

Then the same breakdown rebuilt from the transaction ledger (`txn_*`), a
`*_difference` column for each type that maps one to one onto a total (sale, return,
fee, fee refund, reversal, charge, credit, holdback, release), and `ties_out`, which
is TRUE only when every one of them is within a cent. Filter on `NOT ties_out` to
find the payouts worth a look.

The comparison uses absolute values on both sides, so it cannot be fooled by the
sign question in point 3 above: a difference always means rows are missing or extra.
`TAX`, `COMMISSION` and `CORRECTION` are shown but not tied out, because Klarna
splits them across several totals (tax vs tax refund, commission vs commission
reversal, fee correction) with no documented mapping from type to total.

`effective_fee_rate` is fees plus the tax on them, net of refunded fees, over sales,
for that payout. `merchant_settlement_type` says whether Klarna deducted its fees
from the payout (`NET`) or invoices them separately (`GROSS`); on a gross account the
fees are still reported, they just are not in `settlement_amount`.

## Schema notes

- **`shipping_address_country` is likely always NULL.** The table has the column,
  but Klarna's API names the field `shipping_country`. Staging exposes it as
  `shipping_country` anyway; use `purchase_country` for geography until you have
  confirmed it is populated.
- **The transaction table's merge key does not include `type`.** The connector
  merges transactions on capture, order, refund, payout, merchant references and
  `detailed_type`. If Klarna ever emits two rows that agree on all of those but
  differ only in `type` or `amount`, one would overwrite the other. If a payout fails
  to tie out on fees or tax by an amount that looks like a single line, this is the
  first thing to check.
- **No merchant, order or capture tables.** `merchant_id`, `order_id` and
  `capture_id` are identifiers only; there is nothing to join them to inside the
  connector. Join `merchant_reference_1` (usually your own order number) to your shop
  platform for order context.
- **`vat_amount` is VAT on Klarna's fees**, not on the goods sold. Staging renames
  it `fee_vat_amount` so it cannot be mistaken for sales tax.

## Notes

- **Dates are UTC.** `activity_date` is `sale_date`, falling back to
  `capture_date`. `payout_date` is when the payout was made. A sale captured on the
  30th and paid out on the 3rd lands on the 30th in `daily_settlement_activity` and on
  the 3rd in `payout_reconciliation`; the two agree over a closed month of payouts, not
  at any single day.
- **Fee rates are ratios of sums.** `fee_rate_of_sales` in `fees_by_type` divides
  each row's cost by the whole month's sales, so the rates of the rows in a month add
  up to the total rate. Add them; never average them.
- **Both time series are built on a spine**, so a day or month with no settled
  activity returns zeros instead of disappearing from a chart.
- **Multi-account ready.** Every staging model emits a `klarna_account` label and it
  is part of every join key and every grain. To add a second Klarna connection,
  `UNION ALL` a second block in each staging model with a different label, and
  change nothing else.
- **Nothing here has been run against a warehouse.** Reconcile one month of
  `payout_reconciliation` against the payout reports in the Klarna Merchant Portal
  before relying on any of it. `ties_out` will tell you quickly whether the ledger is
  complete; the Portal tells you whether the numbers are right.

[Klarna connector docs](https://weld.app/docs/applications/klarna) ·
[Klarna Settlements API reference](https://docs.klarna.com/api/settlements/) ·
[Klarna settlement reports](https://docs.klarna.com/settlement-reports)
