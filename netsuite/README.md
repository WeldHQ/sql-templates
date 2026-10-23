# NetSuite templates

Rebuilds NetSuite's core financial reports in your warehouse from the general
ledger lines NetSuite itself reports from: the general ledger, a month-end trial
balance per subsidiary, the income statement by month, and receivables and
payables aging. BigQuery, subsidiary base currency.

Weld connector: **NetSuite**
([docs](https://weld.app/docs/applications/netsuite)).

| Model | Recreates | Grain |
|---|---|---|
| [`weld/core/general_ledger.sql`](weld/core/general_ledger.sql) · [dbt](dbt/models/core/core_netsuite__general_ledger.sql) | "General Ledger" / GL impact | transaction × line × accounting book |
| [`weld/core/trial_balance.sql`](weld/core/trial_balance.sql) · [dbt](dbt/models/core/core_netsuite__trial_balance.sql) | "Trial Balance", at every month end | account × book × subsidiary × month |
| [`weld/core/profit_and_loss_by_month.sql`](weld/core/profit_and_loss_by_month.sql) · [dbt](dbt/models/core/core_netsuite__profit_and_loss_by_month.sql) | "Income Statement" by month | account × book × subsidiary × month |
| [`weld/core/ar_ap_aging.sql`](weld/core/ar_ap_aging.sql) · [dbt](dbt/models/core/core_netsuite__ar_ap_aging.sql) | "A/R Aging" and "A/P Aging" detail, today | open invoice or bill |

Nothing here has been run against a warehouse. Reconcile a closed period against
NetSuite's own reports before relying on the output (see
[Reconciling](#reconciling)).

## How the ledger is built

`transactionaccountingline` is NetSuite's GL impact: one row per transaction line
per accounting book, with the account and the debit or credit in base currency.
It is the same data NetSuite's financial reports read. `general_ledger` joins it
to:

- `transaction`, for the date, type and document number, keeping only posting
  transactions that are not in the deletion log;
- `transactionline`, for the subsidiary, department, class, location and entity;
- `account` and `accounttype`, for the account type, whether it is a balance sheet
  account, and its normal balance.

Lines on statistical and non-posting accounts carry no money and are dropped.
Revenue arrangements are dropped too: the revenue they schedule reaches the
ledger through revenue recognition journals, which are kept.

## Layers

```
raw.netsuite.*            ELT output, untouched
  ↓
weld/staging/*.sql        7 thin wrappers: cast, rename, parse the account type
  ↓
weld/core/*.sql           the reports, all the business logic lives here
  ↓
weld/analytics/*.sql      BI-facing contracts, deliberately thin
```

**Staging** casts and renames. **Core** holds the ledger, balances and aging and
is the layer worth reviewing. **Analytics** is `SELECT *` over core, so dashboards
bind to a name that survives a refactor.

`dbt/` holds the same models with dbt refs, generated from the Weld versions; see
[dbt/README.md](dbt/README.md). With
[GitHub Sync](https://weld.app/docs/transformations/github-sync), Weld references
map to folder paths, so `{{staging.netsuite.transaction}}` expects the model in a
`staging > netsuite` folder.

## Required tables

| Model | Raw tables |
|---|---|
| general ledger | `transactionaccountingline`, `transactionline`, `transaction`, `account`, `accounttype`, `deletedrecord` |
| trial balance | the same |
| profit and loss by month | the same |
| AR/AP aging | `transaction`, `transactionline`, `entity`, `deletedrecord` |

`deletedrecord` needs the "Deleted Record Search" permission, which only the
administrator role has by default. If your role cannot read it, change
`weld/staging/deleted_record.sql` to return no rows (add `WHERE FALSE`); deleted
transactions will then stay in the reports.

## Signs and currency

**Currency.** Ledger amounts are in the **base currency of the line's
subsidiary**, in that accounting book. A OneWorld account with subsidiaries in
different currencies holds several currencies in one table, so every model keeps
`subsidiary_id` in its grain. To consolidate, translate each subsidiary with
NetSuite's consolidated exchange rates first; summing base amounts across
subsidiaries is not a consolidation. In the aging, `open_amount` is in the
transaction currency and `open_amount_base` in the subsidiary's base currency.

**Accounting books.** With Multi-Book Accounting every transaction posts once per
book. `accounting_book_id` is in every grain; filter to your primary book for the
statutory view.

**Debit positive.** `debit` and `credit` are both positive. `net_debit` is
`debit - credit` and sums to zero per transaction, book and subsidiary, which
`assert_netsuite__transactions_balance` checks. The trial balance's `closing_net_debit`
uses the same convention.

**Natural sign.** `amount_natural` in the ledger, `closing_balance_natural` in the
trial balance and `amount` in the P&L are signed by the account type's normal
balance (`accounttype.left`): debit-positive for assets and expenses,
credit-positive for liabilities, equity and income. That is how NetSuite prints
balances.

**Net income.** `net_income_impact` in the P&L is `credit - debit`: income
positive, expenses negative, so a plain `SUM` gives net income.

## Notes

- **Months are calendar months of the transaction date.** NetSuite reports by
  posting period, which can differ from the transaction date when a transaction
  is posted to another open period. `posting_period_id` is on every ledger row; if
  you sync the `accountingperiod` record, join it there and group by period
  instead.
- **Income and expense balances are cumulative in the trial balance.** NetSuite's
  Trial Balance shows them for the fiscal year to date and moves earlier years
  into retained earnings, which needs the fiscal calendar. Compare balance sheet
  accounts with the trial balance, and income and expense accounts with
  `profit_and_loss_by_month`.
- **Removed lines are not logged.** NetSuite logs a deleted transaction in
  `deletedrecord`, but a line deleted from a transaction that still exists simply
  disappears, and an incremental sync cannot see it go. A periodic full resync of
  `transactionaccountingline` and `transactionline` clears stale lines.
  `assert_netsuite__transactions_balance` is the first thing to fail when this has
  happened.
- **Intercompany eliminations.** `is_elimination` on the ledger is the line's
  eliminate flag. NetSuite offsets those lines with journals posted to an
  elimination subsidiary, which show up under that subsidiary's id. For a group
  view, translate every subsidiary (including the elimination subsidiary) to one
  currency and add them up; do not also drop the flagged lines.
- **The aging is gross of credits** and is today's snapshot. Credit memos, vendor
  credits and unapplied payments are not netted in.
- **Multi-account ready.** Every staging model emits a `netsuite_account` label
  that is part of every join key. To add a second NetSuite account, `UNION ALL` a
  second block in each staging model with a different label.

## Reconciling

1. Run the three dbt tests. If `assert_netsuite__transactions_balance` fails, resync before
   reading anything else.
2. In NetSuite, run **Reports → Financial → Income Statement** for a closed month,
   one subsidiary, and compare with `profit_and_loss_by_month` filtered to that
   subsidiary and your primary book. If the totals differ, check for transactions
   whose posting period is not their transaction month.
3. Run **Reports → Financial → Trial Balance** for that subsidiary at the month
   end and compare balance sheet accounts with `closing_balance_natural`.

## Schema notes

- **Not built: posting periods, fiscal-year roll-forward, consolidation.** A
  balance sheet in NetSuite's own form needs three things these templates do not
  have: the accounting period dates (to report by posting period and to split
  income and expense into current-year net income and prior-year retained
  earnings), the fiscal calendar each subsidiary uses, and the consolidated
  exchange rates per period (to translate subsidiaries and derive the
  cumulative translation adjustment). Of these, the standard synced tables
  only include `accountingperiodfiscalcalendars`, which maps periods to calendars
  but carries no dates. The `accountingperiod`, `subsidiary` and
  `consolidatedexchangerate` records may be available, depending on your role, but
  their columns vary by account and cannot be checked against a fixed schema, so
  nothing here depends on them.

- **`account` is not in the public ERD.** Its columns are generated from
  NetSuite's record metadata for your account, so they cannot be checked against
  the ERD. The ones used here
  (`id`, `acct_number`, `acct_name`, `acct_type`, `is_inactive`) are standard
  fields of NetSuite's account record, and reference fields such as `acct_type`
  arrive as a JSON object whose `id` is the account type code. Check the column
  names in your warehouse before the first run.
- Deleted transactions are matched to the deletion log on the record type and id
  (`transaction.recordtype` against `deletedrecord.recordtypeid`), lower-cased on
  both sides. Spot-check one deleted transaction after the first sync.

Vendor docs: the Account record in the NetSuite REST API Browser and in the
SuiteScript Records Browser, and the SuiteQL "Analytics data source" reference for
the `transaction`, `transactionline` and `transactionaccountingline` tables, all in
NetSuite's online help (docs.oracle.com).
