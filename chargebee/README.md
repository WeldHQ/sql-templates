# Chargebee templates

Rebuilds Chargebee's MRR movements in your warehouse from invoices and credit
notes: new, expansion, contraction, churn and reactivation, by month and by
customer, plus what was billed, credited and collected each month. BigQuery.

Weld connector: **Chargebee** ([docs](https://weld.app/docs/applications/chargebee)).

| Model | Recreates | Grain |
|---|---|---|
| [`weld/core/mrr_movements.sql`](weld/core/mrr_movements.sql) · [dbt](dbt/models/core/core_chargebee__mrr_movements.sql) | MRR movements (the MRR bridge) | month × currency |
| [`weld/core/mrr_by_customer_month.sql`](weld/core/mrr_by_customer_month.sql) · [dbt](dbt/models/core/core_chargebee__mrr_by_customer_month.sql) | MRR and its movement per customer | month × customer × currency |
| [`weld/core/billing_by_month.sql`](weld/core/billing_by_month.sql) · [dbt](dbt/models/core/core_chargebee__billing_by_month.sql) | invoices and credit notes totalled by month | month × currency |
| [`weld/core/recurring_revenue_lines.sql`](weld/core/recurring_revenue_lines.sql) · [dbt](dbt/models/core/core_chargebee__recurring_revenue_lines.sql) | (input to the MRR models) | invoice or credit note line |

Nothing here has been run against a warehouse. Reconcile a closed month against
the Chargebee UI before relying on the output (see [Reconciling](#reconciling)).

## How MRR is built

**From invoices, not from `subscription.mrr`.** The subscription table is current
state: it says what a subscription is worth today and nothing about last March.
Invoice lines are an immutable record of what was billed for which service period,
so they reproduce any past month, survive deleted subscriptions, and need no
history table.

1. **Recurring lines.** `recurring_revenue_lines` takes every invoice line whose
   `entity_type` is a plan or an add-on (`plan_item_price`, `addon_item_price`,
   or `plan`, `addon` on the legacy catalog) and has a service period. One-off
   charges and setup fees never count. Items switched out of MRR in Chargebee
   (`item.included_in_mrr = false`) are dropped. Credit note lines on the same
   kinds of item are added with a negative sign, which is how a downgrade or an
   immediate cancellation takes the unused part of the old plan back out.
2. **Monthly amount.** Each line is net of discounts, ex tax, and divided by the
   length of its service period in months. A period within 3 days of a whole
   number of months counts as exactly that many (28 to 31 days is 1 month, 365 is
   12), so annual and quarterly plans normalise cleanly. Anything else, typically
   a proration, counts as days / 30.4375.
3. **Snapshot.** A customer's MRR for a month is the sum of the monthly amounts of
   every line whose service period covers the last day of that month (today, for
   the month in progress).
4. **Movements.** Each month is compared with the one before, per customer:

| Movement | Rule | Sign |
|---|---|---|
| new | was 0, now above 0, never had MRR before | + |
| reactivation | was 0, now above 0, had MRR in an earlier month | + |
| expansion | was above 0, now higher | + |
| contraction | was above 0, now lower but above 0 | − |
| churn | was above 0, now 0 | − |

so `beginning_mrr + new + expansion + contraction + churned + reactivation =
ending_mrr` on every row, and
[`assert_chargebee__mrr_movements_reconcile.sql`](dbt/tests/assert_chargebee__mrr_movements_reconcile.sql)
checks it.

Movements are counted per **customer**. A customer switching from plan A to plan B
is an expansion or a contraction, not a churn plus a new, which is how Chargebee
and most SaaS reporting count it.

## Currency

**Chargebee stores money in minor units.** Every amount arrives as an integer in
the smallest unit of its currency: $499.99 is `49999`. Staging divides by 100.
Zero-decimal currencies are the exception: Chargebee documents them as stored in
whole units (JPY 15 is `15`), so `JPY`, `KRW`, `XAF` and `XOF` are divided by 1.
If your site bills in another currency without minor units, add it to the list in
`staging/invoice.sql` and `staging/credit_note.sql`. Every model downstream of
staging is in major units.

**MRR is in the invoice currency, and currency is part of every grain.** A site
that bills in EUR and USD gets two rows per month in `mrr_movements`, one per
currency. Never sum `ending_mrr` across currencies. To get one total:

- Join a daily or monthly FX table of your own to `mrr_movements` on month and
  currency, and convert there. That is the usual answer, and it keeps the
  conversion rate visible.
- Or use Chargebee's own rate. `staging.chargebee.invoice` keeps
  `exchange_rate`, which Chargebee describes as the rate used for conversion to
  the site's base currency. Its documentation does not say which way round the
  rate is quoted, so check one invoice against its base-currency value in the
  Chargebee UI before multiplying or dividing by it. The templates do not apply
  it for that reason.

## Layers

```
raw.chargebee.*        ELT output, untouched
  ↓
weld/staging/*.sql     7 thin wrappers: cast, rename, minor units to major units, drop deleted
  ↓
weld/core/*.sql        the reports: all the business logic lives here
  ↓
weld/analytics/*.sql   BI-facing contracts, deliberately thin
```

**Staging** does the dull work once: casts, renames, de-duplicates on the primary
key, drops deleted invoices, credit notes and customers, and converts minor units.
Line items take their currency from the parent invoice or credit note, because
Chargebee does not put one on the line.

**Core** holds the MRR logic. This is the layer worth reviewing.

**Analytics** exists for indirection, not transformation. Dashboards bind to
`analytics.chargebee.mrr_movements`, so core can be renamed or re-grained without
breaking anything downstream. All three are `SELECT *`, deliberately.

`dbt/` holds the same models with dbt refs, generated from the Weld versions, so
the two cannot disagree about the logic. See [dbt/README.md](dbt/README.md).

With [GitHub Sync](https://weld.app/docs/transformations/github-sync) a push deploys
all of them and Weld resolves the dependency order. Weld references map to folder
paths, so `{{staging.chargebee.invoice}}` expects the model in a
`staging > chargebee` folder. Mirror that structure in your synced repo, or adjust
the refs.

## Required tables

| Model | Raw tables |
|---|---|
| recurring revenue lines | `invoice`, `invoice_line_item`, `credit_note`, `credit_note_line_item`, `item_price`, `item` |
| mrr by customer month | the above, plus `customer` |
| mrr movements | the above |
| billing by month | `invoice`, `invoice_line_item`, `credit_note` |

`invoice_line_item` and `credit_note_line_item` are created by the `invoice` and
`credit_note` streams. `item_price` and `item` only have rows on Product Catalog
2.0; on the legacy catalog they can be empty and every plan and add-on line
counts towards MRR.

## Reconciling

- **MRR today.** Sum `subscription.mrr` (divided by 100) over subscriptions with
  status `active` or `non_renewing`, per currency, and compare with `ending_mrr`
  for the current month in `mrr_movements`. Expect a small gap: Chargebee updates
  `subscription.mrr` asynchronously and calculates it from the subscription's
  current items, while this model reads what was invoiced.
- **MRR history.** Compare a closed month with Chargebee's MRR report in
  RevenueStory or the Chargebee dashboard. Differences usually come from MRR
  settings on the Chargebee side (whether discounts reduce MRR, how trials and
  metered items count); the rules used here are listed above.
- **Billing.** `billing_by_month.invoice_total` should match the invoice export
  for the month, filtered to non-voided invoices.
- [`assert_chargebee__lines_tie_to_invoice_sub_total.sql`](dbt/tests/assert_chargebee__lines_tie_to_invoice_sub_total.sql)
  checks that invoice lines net of discounts add up to each invoice's
  `sub_total`. MRR depends on that identity, so run it first.

## Notes

- **The month in progress is provisional.** A renewal shows up when its invoice
  is generated, and usage billed in arrears shows up when it is invoiced. Until
  then the customer looks churned or contracted for the current month.
  `is_current_month` flags those rows.
- **A mid-period plan change is approximate for one month.** Chargebee prorates
  by the actual days in the billing period; normalising a prorated line by
  days / 30.4375 can leave the snapshot a few percent of that subscription's MRR
  off in the month of the change. It is exact again from the next renewal.
- **Credit notes lower MRR whatever their reason code.** A goodwill credit for a
  plan period reduces MRR for that period, the same as a downgrade credit. MRR is
  floored at 0 if credits in a month exceed charges.
- **Voided invoices and credit notes are excluded.** Pending invoices (not yet
  closed, common with metered billing) are included.
- **Gifted, paused and trial subscriptions** count when, and only when, they are
  invoiced a non-zero recurring amount.

## Schema notes

Checked against both the public ERD and Weld's stream definitions; the tables and
columns used here match in both. Three limits of the synced schema shape the
models:

- **No `subscription_id` on invoice lines.** Chargebee's API has one, but Weld's
  `invoice_line_item` table does not carry it. A line is tied to a subscription
  only through `invoice.subscription_id`, which is empty on consolidated invoices
  covering several subscriptions. That is one reason MRR movements are at
  customer grain; `recurring_revenue_lines.subscription_id` is filled where known.
- **No base-currency amounts.** Invoices carry `exchange_rate` but no amount in
  the site's base currency, hence the currency section above.
- **`subscription.mrr` is current state only.** Without a history table on the
  `subscription` stream it cannot show past months, which is why it is used only
  for reconciliation.

[Chargebee invoice API](https://apidocs.chargebee.com/docs/api/invoices) ·
[Credit note API](https://apidocs.chargebee.com/docs/api/credit_notes) ·
[Subscription API](https://apidocs.chargebee.com/docs/api/subscriptions) ·
[Zero-decimal currencies](https://www.chargebee.com/docs/billing/2.0/kb/product-catalog/what-are-zero-decimal-currencies)
