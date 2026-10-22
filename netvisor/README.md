# Netvisor templates

Rebuilds Netvisor's core accounting reports in your warehouse: the general ledger, a
monthly trial balance, a monthly income statement and payables aging. BigQuery, in the
company's accounting currency (EUR for a Finnish company).

Weld connector: **Netvisor** ([docs](https://weld.app/docs/applications/netvisor)).

| Model | Recreates | Grain |
|---|---|---|
| [`weld/core/general_ledger.sql`](weld/core/general_ledger.sql) · [dbt](dbt/models/core/core_netvisor__general_ledger.sql) | Pääkirja | voucher × line |
| [`weld/core/trial_balance_by_month.sql`](weld/core/trial_balance_by_month.sql) · [dbt](dbt/models/core/core_netvisor__trial_balance_by_month.sql) | Saldoluettelo, per month | month × account |
| [`weld/core/profit_and_loss_by_month.sql`](weld/core/profit_and_loss_by_month.sql) · [dbt](dbt/models/core/core_netvisor__profit_and_loss_by_month.sql) | Tuloslaskelma, per month | month × account |
| [`weld/core/payables_aging.sql`](weld/core/payables_aging.sql) · [dbt](dbt/models/core/core_netvisor__payables_aging.sql) | Ostoreskontra, open invoices | open purchase invoice (snapshot) |

Nothing here has been run against a warehouse. The SQL parses and every column is
checked against Weld's Netvisor stream definitions, but reconcile a closed month against
Netvisor's own reports before relying on the output (see [Reconciling](#reconciling)).

## Layers

```
raw.netvisor.*           ELT output, untouched
  ↓
weld/staging/*.sql       thin wrappers: unnest the voucher lines, cast, de-duplicate;
                         one static account-range map
  ↓
weld/core/*.sql          the reports, all the business logic
  ↓
weld/analytics/*.sql     BI-facing contracts, deliberately thin
```

`dbt/` holds the same models with dbt refs, generated from the Weld versions; see
[dbt/README.md](dbt/README.md). With
[GitHub Sync](https://weld.app/docs/transformations/github-sync), `{{staging.netvisor.voucher_lines}}`
expects the model in a `staging > netvisor` folder.

## Required tables

| Model | Raw tables |
|---|---|
| general ledger | `accounting_ledger` |
| trial balance by month | `accounting_ledger` |
| profit and loss by month | `accounting_ledger` |
| payables aging | `purchase_invoice` |

`staging/finnish_account_groups.sql` is a static map with no raw source; see below.

## Sign conventions and currency

- **One currency.** The accounting ledger is in the company's accounting currency, EUR
  for a Finnish company. Voucher lines carry no currency column.
- **`amount` is Netvisor's own line sum: debit positive, credit negative.** Every valid
  voucher sums to zero. `debit` and `credit` split it into two non-negative columns.
- **`profit_and_loss_by_month.amount` is flipped to credit positive**, so revenue is
  positive, costs negative, and a plain `SUM(amount)` is the result for the period.
- **Purchase invoices have no currency code** in the synced payload, so `payables_aging`
  treats amounts as EUR. If you book foreign-currency purchase invoices, compare a few
  with Netvisor before trusting the totals.

## The account map, and what Netvisor does not sync

Netvisor's chart of accounts is not part of the synced data, so there are no account
names or account types. `staging/finnish_account_groups.sql` groups accounts by number
range, using the four-digit layout most Finnish charts follow:

| Range | Line |
|---|---|
| 1000-1999 | assets |
| 2000-2999 | equity and liabilities |
| 3000-3999 | net sales |
| 4000-4999 | materials and services |
| 5000-6799 | personnel expenses |
| 6800-6999 | depreciation and impairment |
| 7000-8999 | other operating expenses |
| 9000-9799 | financial items |
| 9800-9899 | appropriations |
| 9900-9999 | income taxes |

Charts are company specific. **Check these ranges against your own chart** (Netvisor:
Kirjanpito, Tilikartta) and edit that one file; every core model reads its grouping from
it. To get account names, add a small mapping table of your own and join it on
`account_number`.

## Things to know before trusting a balance

**Opening balances.** The trial balance accumulates balance sheet accounts over every
voucher synced. A fresh connection syncs vouchers from 1 January 2022 onwards, so a
company with earlier history starts from zero in January 2022 rather than from its real
balances. The period movements and the income statement are correct regardless; balance
sheet closing balances match Netvisor only once the opening position is in the data.
Either sync from the company's first entries or add an opening balance row per account
yourself.

**Back-dated vouchers.** Netvisor's ledger endpoint selects vouchers by voucher date.
Incremental syncs ask for vouchers dated from the previous sync onwards, so a voucher
entered today but dated into an earlier month, and the invalidation of an older voucher,
are picked up by a full re-sync of the `accounting_ledger` stream rather than by the next
incremental run. Before closing a month in your reporting, run a full re-sync of that
stream.

**Prior years' results.** Income statement accounts restart at the beginning of each
fiscal year, and the previous year's result is not booked to equity as a voucher. So the
closing balances in `trial_balance_by_month` do not sum to zero across all accounts; the
period movements do, and the test checks that. Set `fiscal_year_start_month` in that
model if your fiscal year does not start in January.

**Voucher status.** Netvisor returns valid, invalidated and deleted vouchers. Only valid
ones are in the core models; staging keeps the status for audit.

**Receivables aging is not built.** The sales invoice stream has the invoice amount, due
date and a status, but no open or paid amount, so a receivables balance per invoice
cannot be computed honestly from it. Partial payments would be invisible. The purchase
invoice stream has `paid_amount`, which is why payables aging is built and receivables
aging is not.

## Reconciling

- `general_ledger` for one account and month against Pääkirja in Netvisor.
- `profit_and_loss_by_month` summed over a closed fiscal year against Tuloslaskelma.
- `trial_balance_by_month` period movements against Saldoluettelo for the same month;
  closing balances only once opening balances are in place (see above).
- `payables_aging` against the open purchase invoices list with the same as-of date.

## Schema notes

The Weld ERD for Netvisor and the connector's stream definitions agree on every column
used here. The voucher lines are not separate columns: `accounting_ledger.voucher_line`
is a JSON array whose element keys are camelCase (`netvisorKey`, `lineSum`,
`accountNumber`, `description`, `vatPercent`, `vatCode`, `accountDimension`,
`dimension`). The ERD shows the column as a plain string; staging parses it.

## Netvisor references

- [How the Netvisor API works](https://support.netvisor.fi/en/articles/766845-how-netvisor-api-works)
- Netvisor API resources used: "Get accounting data" (`accountingledger.nv`) and "Get purchase invoice" (`getpurchaseinvoice.nv`), both documented in the Netvisor support centre
