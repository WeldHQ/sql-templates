# Adyen templates

Rebuilds Adyen's settlement and payment accounting reports in your warehouse:
what each settlement batch paid you and why, what each payment method costs, every
payment's path from authorisation to payout, and your authorisation rate. BigQuery.

Weld connector: **Adyen** ([docs](https://weld.app/docs/applications/adyen)).

| Model | Recreates | Grain |
|---|---|---|
| [`weld/core/settlement_batches.sql`](weld/core/settlement_batches.sql) · [dbt](dbt/models/core/core_adyen__settlement_batches.sql) | Settlement details report, per batch, tied to the payout | merchant account × batch number × net currency |
| [`weld/core/fees_by_payment_method.sql`](weld/core/fees_by_payment_method.sql) · [dbt](dbt/models/core/core_adyen__fees_by_payment_method.sql) | Settled volume and fees per payment method, with interchange, scheme fees and markup | day × merchant account × payment method × variant × net currency |
| [`weld/core/payment_lifecycle.sql`](weld/core/payment_lifecycle.sql) · [dbt](dbt/models/core/core_adyen__payment_lifecycle.sql) | Payment accounting report, one row per payment | merchant account × PSP reference |
| [`weld/core/authorisation_rate.sql`](weld/core/authorisation_rate.sql) · [dbt](dbt/models/core/core_adyen__authorisation_rate.sql) | Authorisation rate by payment method | day × merchant account × payment method × payment currency |

**Two reports, two questions.** The Settlement details report is the cash view: one
row per entry in a payout batch, from settled payments to Adyen's invoice deductions
to the payout itself. The Payment accounting report is the payment view: one row
per step a payment takes (Received, Authorised, SentForSettle, Settled, Refunded,
Chargeback). Finance reconciles payouts with the first; operations and payments
teams track conversion and lifecycle with the second.

## Layers

```
raw.adyen.*            ELT output, untouched
  ↓
weld/staging/*.sql     2 thin wrappers: cast, rename, sign, classify, de-duplicate
  ↓
weld/core/*.sql        the reports: all the business logic lives here
  ↓
weld/analytics/*.sql   BI-facing contracts, deliberately thin
```

**Staging** casts every column, signs amounts (credits positive, debits negative),
classifies journal and record types once, and removes re-delivered rows.

**Core** holds the batch reconciliation, the fee breakdown and the lifecycle
roll-up. This is the layer worth reviewing.

**Analytics** is `SELECT *` over core, so dashboards bind to a stable name and core
stays free to change.

`dbt/` holds the same models with dbt refs, generated from the Weld versions. See
[dbt/README.md](dbt/README.md).

With [GitHub Sync](https://weld.app/docs/transformations/github-sync) a push deploys
all of them and Weld resolves the dependency order. Weld references map to folder
paths, so `{{staging.adyen.settlement_detail}}` expects the model in a
`staging > adyen` folder.

## Required tables

| Model | Raw tables |
|---|---|
| settlement batches | `settlement_detail_report` |
| fees by payment method | `settlement_detail_report` |
| payment lifecycle | `payments_accounting_report` |
| authorisation rate | `payments_accounting_report` |

The connector receives reports as Adyen generates them, so a report only lands in
your warehouse if it is set to generate automatically in the Customer Area
(Reports, then the report, then automatic generation). The Settlement details report
is generated once per batch; the Payment accounting report once a day.

**Optional columns used.** `payments_accounting_report` uses a few columns Adyen
only includes when you add them to the report: `creation_date`, `payout_date`,
`payable_batch`, `acquirer`, `store`, `shopper_reference` and
`modification_psp_reference`. If your report does not have them, remove those lines
from [`weld/staging/payment_accounting.sql`](weld/staging/payment_accounting.sql)
and the matching `ANY_VALUE` lines in core, or add the columns in the Customer Area.

## Units and signs

**Amounts are in major units.** Every Adyen report writes amounts as decimals in
the currency's major unit (EUR 12.34 is `12.34`). The Adyen API uses minor units
(`1234`), and that is the source of most "our Adyen numbers are 100 times off"
problems, but this connector reads the reports, so no conversion is applied and
none should be.

**Currencies.** Settlement amounts are in the net currency, the currency Adyen pays
you in. Every core model keeps the currency in its grain, so nothing is summed
across currencies. To report in one currency, join to the
[`forex-v2`](../forex-v2/) daily rates table on date and currency.

**Settlement signs.** In staging, `net_amount_nc` is net credit minus net debit, so
settled payments are positive and refunds, chargebacks, Adyen fees and the payout
are negative. Fee columns (`transaction_fees`, `interchange`, `scheme_fees`,
`markup`, `commission`) are positive when they are a cost, and are already deducted
inside the net amounts.

**Commission or the split, never both.** Adyen fills either `Commission` (blended
pricing, or no interchange level data from the acquirer) or the three way split
`Markup`, `Scheme Fees`, `Interchange`, leaving the other side empty. Total
transaction fees are therefore the sum of all four.

**Payment accounting signs** are kept exactly as Adyen books them on each register.
Adyen does not publish the sign per record type, so check one settled and one
refunded payment in your own data before relying on `settled_payable` and
`refunded_payable` individually. `net_payable`, the plain sum of the Payable
register, does not depend on that.

## Reconciling against Adyen

Nothing here has been run against a live warehouse. Reconcile before relying on it:

- **Settlement batches**: pick a paid-out batch and compare `payout` to the
  MerchantPayout line in the Customer Area and to your bank statement.
  [`tests/assert_batch_entries_tie_to_payout.sql`](dbt/tests/assert_batch_entries_tie_to_payout.sql)
  checks that every paid-out batch's entries sum to its payout. It is the most
  valuable test in the set, because the payout is a figure Adyen computed
  independently.
- **Fees by payment method**: compare a month's `transaction_fees` per payment
  method to the Customer Area's fee overview or to your invoice.
- **Authorisation rate**: compare to the Customer Area's authorisation rate. Expect
  a small gap: Adyen can exclude some refusal reasons and group retries, while this
  model counts every PSP reference once.

## Schema notes

- **Report columns are discovered, not fixed.** The connector reads each report CSV
  and names columns after its headers in snake case (`Gross Debit (GC)` becomes
  `gross_debit_gc`). Columns therefore depend on how your report is configured in
  the Customer Area, and their types are inferred from a sample, so a column can be
  FLOAT64 in one warehouse and STRING in another. Staging casts every column
  explicitly for that reason. Header names starting with a digit get an `n_` prefix.
- **Only the two reports above have known columns in the public schema.** The
  connector offers about 30 report streams (dispute, interchange and scheme fee,
  received payments, balance platform reports and more), but none of them has a
  column list in the public schema yet, so no template is built on them.
- **No Time Zone column in some exports.** Adyen documents the time zone column of
  the Settlement details report as present in spreadsheet exports only; the
  connector's schema includes `time_zone`, so it is used. If yours is empty, the
  timestamps are in your account's Customer Area time zone.
- **Times are local, not UTC.** `creation_date` and `booking_date` are wall clock
  times in the report's time zone. Weld stores them as timestamps without a zone,
  so staging reads them back as DATETIME. Adyen's time zone codes (`CET`, `CEST`)
  are not all valid IANA names, which is why nothing converts to UTC.
- **De-duplication by row content.** Each row's `row_checksum` is a hash of its
  content, and the stream is keyed on it, so a report delivered twice does not
  double. The same report generated at both company and merchant account level
  with different column settings produces different checksums: generate each report
  at one level only.
- **`payout_date` and `payable_batch`** are typed as numbers in the public schema.
  Staging casts through STRING so they parse whichever type your warehouse has.

## Links

- [Settlement details report](https://docs.adyen.com/reporting/settlement-reconciliation/transaction-level/settlement-details-report)
- [Payment accounting report](https://docs.adyen.com/reporting/invoice-reconciliation/payment-accounting-report)
