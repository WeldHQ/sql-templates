# Fortnox templates

Rebuilds Fortnox's core accounting reports in your warehouse: the general ledger, the
trial balance per financial year, a monthly income statement on the BAS layout, and
receivables and payables aging. BigQuery, SEK.

Weld connector: **Fortnox** ([docs](https://weld.app/docs/applications/fortnox)).

| Model | Recreates | Grain |
|---|---|---|
| [`weld/core/general_ledger.sql`](weld/core/general_ledger.sql) · [dbt](dbt/models/core/core_fortnox__general_ledger.sql) | Huvudbok | financial year × voucher series × voucher number × row |
| [`weld/core/trial_balance.sql`](weld/core/trial_balance.sql) · [dbt](dbt/models/core/core_fortnox__trial_balance.sql) | Saldobalans | financial year × account |
| [`weld/core/profit_and_loss_by_month.sql`](weld/core/profit_and_loss_by_month.sql) · [dbt](dbt/models/core/core_fortnox__profit_and_loss_by_month.sql) | Resultaträkning, per month | financial year × month × account |
| [`weld/core/receivables_aging.sql`](weld/core/receivables_aging.sql) · [dbt](dbt/models/core/core_fortnox__receivables_aging.sql) | Kundreskontra, förfallna | open customer invoice (snapshot) |
| [`weld/core/payables_aging.sql`](weld/core/payables_aging.sql) · [dbt](dbt/models/core/core_fortnox__payables_aging.sql) | Leverantörsreskontra, förfallna | open supplier invoice (snapshot) |

Nothing here has been run against a warehouse. The SQL parses and every column is
checked against Weld's Fortnox stream definitions, but reconcile a closed month against
the Fortnox reports before relying on the output (see [Reconciling](#reconciling)).

## Layers

```
raw.fortnox.*            ELT output, untouched
  ↓
weld/staging/*.sql       7 thin wrappers: cast, rename, de-duplicate; one static BAS map
  ↓
weld/core/*.sql          the reports, all the business logic
  ↓
weld/analytics/*.sql     BI-facing contracts, deliberately thin
```

Staging casts, renames and keeps the latest copy of each record. Core holds the
ledger logic. Analytics models are `SELECT *` over core so dashboards bind to a name that
does not change when core does. `dbt/` holds the same models with dbt refs, generated
from the Weld versions; see [dbt/README.md](dbt/README.md).

With [GitHub Sync](https://weld.app/docs/transformations/github-sync) a push deploys all
of them and Weld resolves the dependency order. `{{staging.fortnox.vouchers}}` expects
the model in a `staging > fortnox` folder; mirror that structure or adjust the refs.

## Required tables

| Model | Raw tables |
|---|---|
| general ledger | `voucher_rows`, `vouchers`, `accounts`, `financial_years` |
| trial balance | the same |
| profit and loss by month | the same |
| receivables aging | `invoices` |
| payables aging | `supplier_invoices` |

`staging/bas_account_groups.sql` is a static map with no raw source; see below.

## Sign conventions and currency

- **Everything in the ledger is SEK.** Fortnox keeps its books in SEK; voucher rows carry
  no currency column.
- **`amount` is debit minus credit.** Assets and costs are positive, liabilities, equity
  and revenue negative, and every voucher sums to zero. Fortnox's own balances on the
  account (`balance_brought_forward`, `balance_carried_forward`) use the same sign.
- **`profit_and_loss_by_month.amount` is flipped to credit positive**, so revenue is
  positive, costs negative, and a plain `SUM(amount)` is the result for the period.
  `general_ledger.amount_credit_positive` is the same flip at row level.
- **Invoices are in their own currency.** `balance` and `total` on the aging models are
  in the invoice's `currency`. The `_sek` columns convert with the rate booked on the
  invoice (`amount * currency_rate / currency_unit`), which is what the ledger carries.
  Sum `_sek` columns across invoices, never the document-currency ones. The aging is not
  revalued at today's rate; Fortnox's own reskontra shows booked SEK too.

## The BAS map

`staging/bas_account_groups.sql` maps account number ranges to report lines, following
the Swedish BAS chart and the statutory cost-by-nature income statement:

| Range | Line |
|---|---|
| 1000-1999 | assets |
| 2000-2999 | equity and liabilities |
| 3000-3799 | net sales |
| 3800-3999 | other operating income |
| 4000-4999 | goods and materials |
| 5000-6999 | other external expenses |
| 7000-7699 | personnel expenses |
| 7700-7899 | depreciation and write-downs |
| 7900-7999 | other operating expenses |
| 8000-8799 | financial items |
| 8800-8899 | appropriations |
| 8900-8989 | income tax |
| 8990-8999 | result for the year (excluded from the P&L) |

Fortnox does not expose an account type, so the range is the only structure available.
Most Swedish companies stay close to BAS; if yours does not, edit the ranges in that one
file and every core model follows.

8999 (Årets resultat) is where the year's result is booked against equity at year end.
It is kept in the general ledger and the trial balance and excluded from
`profit_and_loss_by_month`, which would otherwise net to zero in the closing month.

## Notes

- **Financial years, not calendar years.** Fortnox keeps a separate chart, with its own
  opening balance, for every financial year (räkenskapsår), and voucher numbers restart
  each year. `financial_year_id` is part of every key. A company on a broken fiscal year
  (say May to April) gets correct year totals because grouping is on the Fortnox year,
  not on `EXTRACT(YEAR ...)`.
- **Removed rows are excluded.** When a voucher is corrected, Fortnox strikes through
  the original row and adds a replacement. The struck row still comes through the API
  with `removed = true`; it is kept in staging for audit and filtered out of every core
  model.
- **Cash method companies.** Under kontantmetoden, invoices only reach the ledger when
  paid, so the ledger and the aging models describe different things until then.
  `financial_years.accounting_method` says which method a year uses.
- **Aging is a snapshot.** Buckets are computed against `CURRENT_DATE()` and no history is
  kept. Materialise a dated copy on a schedule if you need aging over time. Buckets are
  days past the due date: not due, 1-30, 31-60, 61-90, over 90.
- **Single company.** Each Fortnox connection is one company. To combine several, add a
  company label column in each staging model and a `UNION ALL` block per connection, and
  add the label to every join key in core.

## Reconciling

- `general_ledger` for one account and month against Huvudbok in Fortnox, filtered to
  the same account and period.
- `trial_balance` for a closed year against Saldobalans. The test
  [`assert_fortnox__trial_balance_ties_to_fortnox.sql`](dbt/tests/assert_fortnox__trial_balance_ties_to_fortnox.sql)
  does this automatically against the closing balance Fortnox stores on each account.
- `profit_and_loss_by_month` summed over a year against Resultaträkning for that year.
- The aging models against Kundreskontra and Leverantörsreskontra with the same as-of
  date.

## Schema notes

The Weld ERD for Fortnox and the connector's stream definitions agree on every table and
column used here. Two behaviours worth knowing:

- `vouchers.year`, `voucher_rows.voucher_year` and `accounts.year` hold the Fortnox
  financial year ID, not a calendar year. They join to `financial_years.id`.
- The `accounts` stream is incremental on the account's modification date. If the stored
  closing balance looks stale for the open year, re-sync that stream.

## Fortnox references

- [Fortnox API reference](https://api.fortnox.se/apidocs) (vouchers, accounts, financial years, invoices, supplier invoices)
- [Fortnox developer guide: vouchers](https://www.fortnox.se/developer/guides-and-good-to-know/best-practices/vouchers)
- [BAS chart of accounts](https://www.bas.se/kontoplaner/)
