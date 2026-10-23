# QuickBooks Online templates

Rebuilds QuickBooks Online's core accounting reports in your warehouse: the
general ledger, a month-end trial balance, the Profit and Loss by month, and
receivables and payables aging. BigQuery, home currency.

Weld connector: **QuickBooks**
([docs](https://weld.app/docs/applications/quickbooks)).

| Model | Recreates | Grain |
|---|---|---|
| [`weld/core/general_ledger.sql`](weld/core/general_ledger.sql) · [dbt](dbt/models/core/core_quickbooks__general_ledger.sql) | "Journal" / "General Ledger" | company × transaction × line |
| [`weld/core/trial_balance.sql`](weld/core/trial_balance.sql) · [dbt](dbt/models/core/core_quickbooks__trial_balance.sql) | "Trial Balance", at every month end | company × month × account |
| [`weld/core/profit_and_loss_by_month.sql`](weld/core/profit_and_loss_by_month.sql) · [dbt](dbt/models/core/core_quickbooks__profit_and_loss_by_month.sql) | "Profit and Loss" by month, accrual basis | company × month × account |
| [`weld/core/ar_ap_aging.sql`](weld/core/ar_ap_aging.sql) · [dbt](dbt/models/core/core_quickbooks__ar_ap_aging.sql) | "A/R Aging Detail" and "A/P Aging Detail", today | company × side × open invoice or bill |

Nothing here has been run against a warehouse. Reconcile a closed month against
the reports in the QuickBooks UI before relying on the output (see
[Reconciling](#reconciling)).

## Why the Journal report

QuickBooks Online has no single "ledger lines" object in its API. Money moves on a
dozen transaction types (invoices, sales receipts, payments, bills, bill payments,
purchases, deposits, transfers, journal entries, credit memos, vendor credits),
each with its own line layout, and most of them only name one side of the entry:
an invoice line names the income account, and the receivable side is implied.
Rebuilding double entry from those streams means re-implementing QuickBooks'
posting rules.

The connector's `journal_report` stream reads QuickBooks' own Journal report
instead: every transaction, already in debit and credit form, one row per account
hit. The first line of each transaction (with its date and type) lands in
`journal_report`, the remaining lines in `journal_report_line`.
`general_ledger` stitches them back together, and everything else is built on it.

The connector also has a `general_ledger_report` stream. It is not used: it is
loaded append-only in monthly windows whose first and last days overlap, so the
same posting can appear more than once, and its amounts come signed per account
rather than as debit and credit.

## Layers

```
raw.quickbooks.*            ELT output, untouched
  ↓
weld/staging/*.sql          6 thin wrappers: cast, rename, keep the latest copy
  ↓
weld/core/*.sql             the reports, all the business logic lives here
  ↓
weld/analytics/*.sql        BI-facing contracts, deliberately thin
```

**Staging** casts, renames and keeps one copy per transaction header. No
business logic.

**Core** holds the ledger, the balances and the aging. This is the layer worth
reviewing.

**Analytics** is `SELECT *` over core, so dashboards can bind to a name that
survives a refactor of core.

`dbt/` holds the same models with dbt refs, generated from the Weld versions; see
[dbt/README.md](dbt/README.md). With
[GitHub Sync](https://weld.app/docs/transformations/github-sync), Weld references
map to folder paths, so `{{staging.quickbooks.account}}` expects the model in a
`staging > quickbooks` folder.

## Required tables

| Model | Raw tables |
|---|---|
| general ledger | `journal_report`, `journal_report_line`, `account` |
| trial balance | the above, plus `company` |
| profit and loss by month | `journal_report`, `journal_report_line`, `account` |
| AR/AP aging | `invoice`, `bill` |

## Signs and currency

**Currency.** Every ledger amount is in the company's **home currency**.
QuickBooks converts foreign-currency transactions at the transaction's exchange
rate before they reach the Journal report. In the aging, `open_balance` is in the
document's own currency (`currency`) and `open_balance_home` is in home currency;
sum the second. For companies without multicurrency, QuickBooks does not return a
home balance and the two are the same.

**Debit positive.** `debit` and `credit` are both positive, as QuickBooks prints
them. `net_debit` is `debit - credit`; it sums to zero over every transaction and
over the whole ledger, which is what the tests check. The trial balance uses this
convention throughout.

**Natural sign.** `amount_natural` in the ledger, and `amount` in the P&L, are
signed by the account's normal balance: debit-positive for Asset and Expense
accounts, credit-positive for Liability, Equity and Revenue. That is how
QuickBooks prints balances, so revenue and expenses both read positive.

**Net income.** `net_income_impact` in the P&L is `credit - debit`: income
positive, expenses negative. A plain `SUM` over rows gives their contribution to
net income: Gross Profit is the sum over the Income and Cost of Goods Sold
sections, Net Income the sum over everything.

## Retained earnings

QuickBooks never posts a year-end closing entry. Its Balance Sheet and Trial
Balance fold earlier fiscal years' net income into Retained Earnings at report
time. `trial_balance` does the same with one extra row per month,
`account_id` NULL, named "Prior fiscal years net income (Retained Earnings)". Add
it to the Retained Earnings account to match the UI. The fiscal year start comes
from the company settings.

## Notes

- **Edits to older transactions are not picked up incrementally.** The Journal
  report is filtered by transaction date, and each incremental run starts at the
  date of the previous run. A transaction dated before that (a backdated entry, or
  an edit to last quarter's invoice) is not re-read until the stream is fully
  resynced. Schedule a periodic full resync of `journal_report` (monthly, before
  closing the books, is a reasonable rhythm). `assert_transactions_balance` is the
  first test to fail when this has happened.
- **Deleted transactions stay in raw** until that full resync, for the same reason.
  The same applies to deleted invoices and bills in the aging.
- **The aging is gross of credits.** QuickBooks' own aging nets unapplied payments,
  open credit memos and vendor credits against the customer or vendor. Those are
  not included, so totals here can be higher than the report's. The model is a
  snapshot of today and cannot be replayed for a past date.
- **The P&L is accrual basis**, because the Journal report is. A cash-basis P&L
  needs payment application data and is not attempted.
- **Account classes.** The API leaves `classification` empty on some accounts.
  Staging fills it in from `account_type`, since each account type belongs to one
  class. Without that, an income or expense account would drop out of the P&L.
  `assert_every_ledger_line_has_a_class` flags any line still left without one.
- **Months come from the transaction date.** QuickBooks has no separate posting
  period, so this matches the UI.
- **Multi-company ready.** Every staging model emits a `quickbooks_company` label
  that is part of every join key in core. To add a company, `UNION ALL` a second
  block in each staging model with a different label.
- Metric definitions were cross-checked against Fivetran's open-source
  `dbt_quickbooks` package; the SQL here is written independently for Weld's
  schema.

## Reconciling

1. Run `assert_transactions_balance` and `assert_trial_balance_sums_to_zero`. If
   either fails, resync `journal_report` before looking at the SQL.
2. In QuickBooks, run **Reports → Profit and Loss** for a closed month on the
   accrual basis and compare the section totals with `profit_and_loss_by_month`
   for that month.
3. Run **Reports → Trial Balance** as of a month end and compare with
   `trial_balance_debit` and `trial_balance_credit` for that month, remembering
   the retained earnings row above.
4. The connector's `trial_balance_report` and `profit_and_loss_report` streams
   load those reports directly and can be used for the same comparison in SQL.
   Both are fetched in windows whose boundary dates overlap, so compare
   balance-sheet balances at a single date rather than summing P&L periods.

## Schema notes

- The public ERD shows `bill.txn_date` and `bill.due_date` as strings, which
  matches the connector (they arrive as `YYYY-MM-DD` text on the bill stream,
  unlike the invoice stream). Staging parses them.
- `journal_report.transaction_id` is the column QuickBooks labels "Transaction
  Type" id; the connector renames it. Lines join to it on transaction id and
  document number, which is also how the connector keys them.

Vendor docs: the "Run the Profit and Loss report" and "Trial Balance" articles
in QuickBooks Learn & Support (quickbooks.intuit.com), and the Account, Invoice,
Bill and JournalReport reference in the Accounting API section of Intuit's
developer site (developer.intuit.com).
