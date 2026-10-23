# Microsoft Dynamics 365 Business Central templates

Rebuilds Business Central's core accounting reports in your warehouse: the general
ledger, a monthly trial balance, a monthly income statement by account category, and
receivables aging at invoice level. BigQuery, in each company's local currency (LCY).

Weld connector: **Business Central**
([docs](https://weld.app/docs/applications/microsoft-business-central)).

| Model | Recreates | Grain |
|---|---|---|
| [`weld/core/general_ledger.sql`](weld/core/general_ledger.sql) · [dbt](dbt/models/core/core_business_central__general_ledger.sql) | G/L Entries, Detail Trial Balance | company × G/L entry |
| [`weld/core/trial_balance_by_month.sql`](weld/core/trial_balance_by_month.sql) · [dbt](dbt/models/core/core_business_central__trial_balance_by_month.sql) | Trial Balance, per month end | company × month × account |
| [`weld/core/profit_and_loss_by_month.sql`](weld/core/profit_and_loss_by_month.sql) · [dbt](dbt/models/core/core_business_central__profit_and_loss_by_month.sql) | Income Statement, per month | company × month × account |
| [`weld/core/receivables_aging.sql`](weld/core/receivables_aging.sql) · [dbt](dbt/models/core/core_business_central__receivables_aging.sql) | Aged Accounts Receivable, at invoice level | open sales invoice (snapshot) |

Nothing here has been run against a warehouse. The SQL parses and every column is
checked against the schema Weld syncs for Business Central, but reconcile a closed month
against Business Central's own reports before relying on the output (see
[Reconciling](#reconciling)).

## Layers

```
raw.business_central.*    ELT output, untouched
  ↓
weld/staging/*.sql        4 thin wrappers: cast, rename, de-duplicate, classify accounts
  ↓
weld/core/*.sql           the reports, all the business logic
  ↓
weld/analytics/*.sql      BI-facing contracts, deliberately thin
```

`dbt/` holds the same models with dbt refs, generated from the Weld versions; see
[dbt/README.md](dbt/README.md). With
[GitHub Sync](https://weld.app/docs/transformations/github-sync),
`{{staging.business_central.accounts}}` expects the model in a
`staging > business_central` folder.

## Required tables

| Model | Raw tables |
|---|---|
| general ledger | `general_ledger_entry`, `account`, `company_information` |
| trial balance by month | the same |
| profit and loss by month | the same |
| receivables aging | `sales_invoice`, `company_information` |

## Sign conventions and currency

- **G/L entries are in local currency (LCY).** Business Central posts every entry in the
  company's local currency, whatever currency the document was in. `local_currency_code`
  comes from `company_information`. If you use an additional reporting currency, those
  amounts are not part of the synced G/L entry and are not here.
- **Several companies, several currencies.** One connection can sync several companies,
  and `company_id` is part of every grain. Companies can have different local
  currencies, so never sum across companies without converting first.
- **`amount` is debit minus credit.** Assets and expenses positive; liabilities, equity
  and income negative. Each company's ledger sums to zero.
- **`profit_and_loss_by_month.amount` is flipped to credit positive**, so income is
  positive, costs negative, and `SUM(amount)` is the result for the period.
- **Receivables are in document currency.** `remaining_amount` on a sales invoice is in
  the invoice's currency, and the stream carries no exchange rate. Sum per
  `currency_code`. Business Central's own aged report (the `aged_accounts_receivable`
  stream) is in LCY.

## Account structure

Business Central exposes the account category on every G/L account: Assets,
Liabilities, Equity, Income, Cost of Goods Sold, Expense, plus a subcategory. Staging maps
the first three to `balance_sheet` and the last three to `income_statement`, the same
split as Business Central's Income/Balance field. Accounts without a category come out as
`unclassified` and are left out of the income statement; check
`general_ledger` for any rows with that value.

## Notes

- **Closing entries.** When a fiscal year is closed with "Close Income Statement",
  Business Central posts entries that move every income statement balance to retained
  earnings, dated on the last day of the year. Internally they carry a closing date;
  the API returns an ordinary posting date. They belong in the trial balance, which then
  matches Business Central, but they would zero the last month of the year in the
  income statement. List the document numbers you used for them in the
  `closing_documents` CTE at the top of `profit_and_loss_by_month` and they are excluded.
- **Balances need full history.** The trial balance accumulates every synced entry. The
  G/L entry stream's first sync reads the full history, so this holds unless a sync was
  cut short.
- **Receivables aging differs from Business Central's aged report by design.** It
  reads posted sales invoices with status Open. Unapplied credit memos and payments are
  not in that stream, so they are not netted; Business Central's Aged Accounts
  Receivable nets them. Use this model to see which invoices are late, and the
  `aged_accounts_receivable` stream for the total.
- **Aging is a snapshot.** Buckets are computed against `CURRENT_DATE()`: not due, 1-30,
  31-60, 61-90, over 90 days past due.
- **Dimensions.** Global and shortcut dimensions are synced in
  `general_ledger_entry_dimension_set_line`, one row per entry and dimension. They are
  not joined here because that would multiply ledger rows; pivot the dimension you need
  to one column per entry first, then join on `company_id` and the entry ID.

## Reconciling

- `general_ledger` for one account and month against the G/L Entries page filtered the
  same way.
- `trial_balance_by_month` at a month end against the Trial Balance report with that
  date filter. The synced `trial_balance` stream is Business Central's own trial balance
  for the date in its `date_filter`, and is a ready reference.
- `profit_and_loss_by_month` summed over a closed fiscal year against the Income
  Statement report, after listing the closing documents.
- `receivables_aging` per customer against Aged Accounts Receivable, allowing for
  unapplied credit memos and payments.

## Schema notes

The Weld ERD for Business Central and the schema Weld syncs agree on every column
used here. Behaviour worth knowing:

- `posting_date`, `invoice_date` and `due_date` arrive as strings (`YYYY-MM-DD`) and are
  parsed in staging.
- The G/L entry stream is incremental on `lastModifiedDateTime` with an overlap window,
  so the same entry can arrive more than once; staging keeps the latest copy per
  `(company_id, id)`.

## Business Central references

- [generalLedgerEntry resource type](https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/api-reference/v2.0/resources/dynamics_generalledgerentry)
- [account resource type](https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/api-reference/v2.0/resources/dynamics_account)
- [salesInvoice resource type](https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/api-reference/v2.0/resources/dynamics_salesinvoice)
- [Close years and periods](https://learn.microsoft.com/en-us/dynamics365/business-central/year-close-years-periods)
