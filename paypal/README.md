# PayPal templates

Turns PayPal's transaction feed into a daily settlement summary and a classified
transaction ledger, tied back to the balance PayPal reports. BigQuery, one row per
PayPal currency balance, never converted.

Weld connector: **PayPal**
([docs](https://weld.app/docs/applications/paypal)).

| Model | Recreates | Grain |
|---|---|---|
| [`weld/core/daily_balance_activity.sql`](weld/core/daily_balance_activity.sql) · [dbt](dbt/models/core/core_paypal__daily_balance_activity.sql) | Balance report totals: payments, refunds, chargebacks, fees, withdrawals, net change | day × currency |
| [`weld/core/transactions.sql`](weld/core/transactions.sql) · [dbt](dbt/models/core/core_paypal__transactions.sql) | Activity download, classified, with gross, fee and net | transaction id × event code |
| [`weld/core/balance_reconciliation.sql`](weld/core/balance_reconciliation.sql) · [dbt](dbt/models/core/core_paypal__balance_reconciliation.sql) | Today's balance against the synced history | account × currency |

## Signs, units and currency

- **Major units, decimal.** PayPal sends amounts as decimal strings (`"12.50"`), not
  cents. Staging casts them to `NUMERIC` without scaling.
- **Signed from your side.** Money into your PayPal balance is positive, money out is
  negative. A received payment has a positive `gross_amount` and a negative
  `fee_amount`; a refund has a negative `gross_amount` and, where PayPal returns part
  of the fee, a positive `fee_amount`. `net_amount = gross_amount + fee_amount`.
- **Every currency is its own balance.** PayPal keeps a separate balance per
  currency, and every model keeps `currency` in the grain. Nothing is converted.
  When PayPal converts a payment into your primary currency, the conversion appears
  as `currency_conversions`: negative in the currency it left, positive in the one it
  entered. To report a single total, convert each currency's rows at your own rates
  after aggregation.
- **Fees are in the transaction's currency.** `fee_amount` is taken to be in the same
  currency as `gross_amount`, which is how PayPal reports it.

## The daily summary

`daily_balance_activity` includes only balance-affecting records and adds up exactly:

```
payments_received + payments_sent + refunds + chargebacks_and_reversals
+ fees + currency_conversions + bank_deposits + bank_withdrawals
+ holds_and_releases + other
= net_balance_change
```

Payment, refund and chargeback columns are gross. All fees are in `fees`: the fee
on each record plus standalone fee records.

## How records are classified

By PayPal's transaction event code, first three characters:

| Event codes | Category |
|---|---|
| T1107 | `refund` |
| T00xx | `payment_received` or `payment_sent`, by sign |
| T01xx | `fee` |
| T02xx | `currency_conversion` |
| T03xx | `bank_deposit` |
| T04xx | `bank_withdrawal` |
| T11xx (except T1107), T12xx | `chargeback_or_reversal` |
| T13xx | `authorization` (not balance-affecting) |
| T15xx, T21xx | `hold_or_release` |
| T98xx | `informational` (not balance-affecting) |
| anything else | `other` |

`is_balance_affecting` is true for status `S` (completed) and `V` (completed, later
reversed) outside the authorization and informational groups. A reversed payment and
its reversal are separate records, so both count and they net to zero. Pending (`P`)
and denied (`D`) records stay in `transactions` but are excluded from the summary.
Check `other` after the first run: anything large there deserves its own category.

## Layers

```
raw.paypal.*            ELT output, untouched
  ↓
weld/staging/*.sql      2 thin wrappers: cast strings to numbers, rename, de-duplicate
  ↓
weld/core/*.sql         the reports: all the business logic lives here
  ↓
weld/analytics/*.sql    BI-facing contracts, deliberately thin
```

Analytics models are `SELECT *` over core. Dashboards bind to them so core can change
without breaking anything downstream.

`dbt/` holds the same models with dbt refs, generated from the Weld versions. See
[dbt/README.md](dbt/README.md).

With [GitHub Sync](https://weld.app/docs/transformations/github-sync), Weld references
map to folder paths, so `{{staging.paypal.transaction}}` expects the model in a
`staging > paypal` folder.

## Required tables

| Model | Raw tables |
|---|---|
| transactions | `transaction` |
| daily balance activity | `transaction` |
| balance reconciliation | `transaction`, `balance` |

## Notes

- **Three years of history.** PayPal's transaction search only reaches three years
  back, so the synced history starts part-way through an older account's life.
  `balance_reconciliation.implied_opening_balance` is the balance the account must
  have held before the first synced record for today's balance to be right. Use it
  as the opening figure for a running balance.
- **Holds.** Holds and releases (T15, T21) move money between available and withheld
  balance. While a hold is open, `implied_opening_balance` will differ by roughly the
  `withheld_balance`; that difference is expected.
- **Dates are UTC.** PayPal's own reports use the account's timezone, so records near
  midnight can fall on a different day than in the PayPal UI.
- **Delay.** PayPal can take up to three hours to make a transaction searchable, so
  today's figures fill in over the day.
- **Disputes, invoices and subscriptions** are synced by the connector but not
  modelled here. Disputes that move money already appear as chargebacks and
  reversals in the summary.

## Schema notes

The ERD and the connector definition agree on every column used. Timestamp columns
the ERD lists as `date` are loaded as timestamps; staging casts them explicitly.

## Reconciling

Nothing here has been run against a warehouse. Before relying on the output,
reconcile against PayPal: download one month of balance-affecting activity from PayPal and compare the totals per currency with
`daily_balance_activity`, and compare `balance_reconciliation.total_balance` with the
balance shown in PayPal. The dbt tests check internal consistency only.

PayPal references:
[Transaction Search API](https://developer.paypal.com/docs/api/transaction-search/v1/) ·
[Transaction event codes](https://developer.paypal.com/docs/transaction-search/transaction-event-codes/)
