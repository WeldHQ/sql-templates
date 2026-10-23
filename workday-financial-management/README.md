# Workday Financial Management templates

Rebuilds the core accounting views of Workday Financial Management in your
warehouse from posted journal lines: the general ledger, a month-end trial
balance, the income statement by month, and receivables aging. BigQuery,
company base currency.

Weld connector: **Workday Financial Management**
([docs](https://weld.app/docs/applications/workday-financial-management)).

| Model | Recreates | Grain |
|---|---|---|
| [`weld/core/general_ledger.sql`](weld/core/general_ledger.sql) · [dbt](dbt/models/core/core_workday_financial_management__general_ledger.sql) | journal lines, posted | journal entry × line |
| [`weld/core/trial_balance.sql`](weld/core/trial_balance.sql) · [dbt](dbt/models/core/core_workday_financial_management__trial_balance.sql) | "Trial Balance", at every month end | company × ledger × book code × account × month |
| [`weld/core/profit_and_loss_by_month.sql`](weld/core/profit_and_loss_by_month.sql) · [dbt](dbt/models/core/core_workday_financial_management__profit_and_loss_by_month.sql) | income statement by month | company × ledger × book code × account × month |
| [`weld/core/ar_aging.sql`](weld/core/ar_aging.sql) · [dbt](dbt/models/core/core_workday_financial_management__ar_aging.sql) | customer invoice aging, today | open customer invoice |

Nothing here has been run against a warehouse. Reconcile a closed period against
Workday's own Trial Balance and income statement before relying on the output
(see [Reconciling](#reconciling)).

## How the ledger is built

Journal entries arrive with their lines: the headers in `journal_entry` and the
lines in `journal_entry_line`.
`general_ledger` keeps journals whose status is Posted and resolves each line's
ledger account:

- the line carries its account set code (for example "Standard") and the
  account's identifier within that set;
- `account_set` turns the code into the account set's WID;
- `ledger_account` (a child table of `account_set`) holds the account's name and
  ledger account type.

Workday lets every tenant define its own ledger account types, so there is no
fixed list to map from. `weld/staging/ledger_account.sql` derives a standard
classification (Asset, Liability, Equity, Revenue, Expense) from the type's name
by keyword. **Check it against your tenant's types before using the P&L.**
`assert_workday_financial_management__every_line_has_a_classified_account` lists every posted account the
mapping does not cover.

## Layers

```
raw.workday_financial_management.*   ELT output, untouched
  ↓
weld/staging/*.sql                   6 thin wrappers: cast, rename, classify accounts
  ↓
weld/core/*.sql                      the reports, all the business logic lives here
  ↓
weld/analytics/*.sql                 BI-facing contracts, deliberately thin
```

**Staging** casts, renames and holds the account type mapping. **Core** holds the
ledger, balances and aging and is the layer worth reviewing. **Analytics** is
`SELECT *` over core, so dashboards bind to a name that survives a refactor.

`dbt/` holds the same models with dbt refs, generated from the Weld versions; see
[dbt/README.md](dbt/README.md). With
[GitHub Sync](https://weld.app/docs/transformations/github-sync), Weld references
map to folder paths, so `{{staging.workday_financial_management.journal_entry}}`
expects the model in a `staging > workday_financial_management` folder.

## Required tables

| Model | Raw tables |
|---|---|
| general ledger | `journal_entry`, `journal_entry_line`, `account_set`, `ledger_account`, `company` |
| trial balance | the same |
| profit and loss by month | the same |
| AR aging | `customer_invoice`, `company` |

## Signs and currency

**Currency.** Journal lines carry two sets of amounts: `debit` and `credit` in the
line's transaction currency, and ledger amounts in the **ledger currency, the
company's base currency** (`company_currency`, from the company's accounting
setup). Every balance here uses the ledger amounts. Workday can leave them empty
when the transaction is already in the base currency, so the ledger falls back to
the transaction amounts, but only for lines whose currency is the company's base
currency. A foreign-currency line without ledger amounts is kept at 0 and flagged
(`is_ledger_amount_missing`), and `assert_workday_financial_management__no_missing_ledger_amounts` lists them;
converting it with a guessed rate would put the wrong number in the balances. `company_id` is in every grain: do not sum
across companies with different currencies without translating first. The AR
aging is in invoice currency; sum it per `currency`.

**Debit positive.** `ledger_debit` and `ledger_credit` are normally both
positive. A company whose accounting setup keeps the debit or credit side on a
reversal and reverses the sign instead books reversals as negative amounts on the
original side, so negative values are valid there; every net figure below is
right either way.
`net_debit` is `ledger_debit - ledger_credit` and sums to zero over every journal
and company; `assert_workday_financial_management__journals_balance` checks it. The trial balance's
`closing_net_debit` uses the same convention.

**Natural sign.** `amount_natural`, `closing_balance_natural` and the P&L's
`amount` are signed by the account's normal balance: debit-positive for Asset and
Expense, credit-positive for Liability, Equity and Revenue.

**Net income.** `net_income_impact` in the P&L is `credit - debit`: revenue
positive, expenses negative, so a plain `SUM` gives net income.

## Notes

- **Book codes.** A journal without a book code applies to every book; one with a
  book code applies only to that book. Every model keeps `book_code` in the grain.
  For one book, add the NULL rows to that book's rows; for the primary view,
  filter to `book_code IS NULL`.
- **Months are calendar months of the accounting date.** Workday reports by fiscal
  period, from the company's fiscal schedule, which is not part of these tables.
  `ledger_period` is on every ledger row if you need to group by it.
- **Income and expense balances are cumulative in the trial balance.** Workday's
  Trial Balance shows them for the fiscal year to date. Compare balance sheet
  accounts there, income and expense accounts through `profit_and_loss_by_month`.
- **Opening balances need the full history.** Closing balances are cumulative from
  the first journal in the warehouse. If the connection's start date is later than
  the tenant's first journal, period amounts are right and closing balances are
  missing the opening balance.
- **Edited journals can leave stale lines.** Journals are synced by last update,
  and lines are keyed by position. A journal edited to have fewer lines can keep
  its old trailing lines in raw until a full resync, and
  `assert_workday_financial_management__journals_balance` is the first test to show it.
- **The AR aging is partly by invoice age.** `Get_Customer_Invoices` does not
  return the computed due date, only an override when one was set.
  `aging_basis` says whether a row was aged from its due date or its invoice date.
  To age everything by due date, join your payment terms.
- **No AP aging.** The supplier invoice operation does not return an open amount,
  so outstanding payables cannot be computed from it.
- **Posted journals only.** The status filter reads the status code first and the
  display name second, since the display name is translated in tenants that do
  not run in English.
- **Multi-tenant ready.** Every staging model emits a `workday_tenant` label that
  is part of every join key. To add a tenant, `UNION ALL` a second block in each
  staging model with a different label.

## Reconciling

1. Run `assert_workday_financial_management__journals_balance` and `assert_workday_financial_management__every_line_has_a_classified_account`.
   Fix the account type mapping until the second returns no rows.
2. In Workday, run the Trial Balance report for one company and ledger at a period
   end and compare balance sheet accounts with `closing_balance_natural` for the
   matching month and book code.
3. Run the income statement for a closed period and compare with
   `profit_and_loss_by_month` for the same company. Differences usually come from
   periods that do not match calendar months, or from a type the mapping put in
   the wrong class.

## Schema notes

- **Not built: fiscal periods and the retained earnings roll-forward.** Workday
  reports by fiscal period and folds prior fiscal years' income and expense into
  retained earnings. The company record names its fiscal schedule, but the
  schedule's periods and years are not synced, so these models use
  calendar months of the accounting date and leave income and expense cumulative.
- **Not built: translation to one currency.** Currency conversion rates are
  synced, but which rate type and date a consolidation uses is tenant
  configuration that is not in these tables, so no translated balances are
  produced. Every grain keeps `company_id` instead.

- **The public ERD for this connector only covers the purchasing tables**
  (`purchase_order*`, `receipt*`). Every table used here (`journal_entry`,
  `journal_entry_line`, `account_set`, `ledger_account`, `company`,
  `customer_invoice`) is part of the schema Weld syncs, and every column used was
  checked against it.
- `journal_entry_line.account_set_id` holds the account set's **code** (for
  example "Standard"), not its WID, despite the name; it is joined to
  `account_set.account_set_code` for that reason.
- Reference columns ending in `_id` hold Workday WIDs, `_code` the reference's
  other ID, `_descriptor` the display name. The line's ledger account is matched on
  its `_code` against `ledger_account.ledger_account_identifier`; spot-check a few
  accounts after the first sync.
