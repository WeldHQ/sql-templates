# Recurly templates

Rebuilds MRR movements from Recurly's invoiced line items: new, expansion,
contraction, churn and reactivation, by month and by customer, plus what was
billed, credited and collected each month, and why subscriptions ended.
BigQuery.

Weld connector: **Recurly** ([docs](https://weld.app/docs/applications/recurly)).

| Model | Recreates | Grain |
|---|---|---|
| [`weld/core/mrr_movements.sql`](weld/core/mrr_movements.sql) · [dbt](dbt/models/core/core_recurly__mrr_movements.sql) | MRR movements (the MRR bridge) | month × currency |
| [`weld/core/mrr_by_customer_month.sql`](weld/core/mrr_by_customer_month.sql) · [dbt](dbt/models/core/core_recurly__mrr_by_customer_month.sql) | MRR and its movement per account | month × account × currency |
| [`weld/core/billing_by_month.sql`](weld/core/billing_by_month.sql) · [dbt](dbt/models/core/core_recurly__billing_by_month.sql) | charge and credit invoices totalled by month | month × currency |
| [`weld/core/subscription_churn.sql`](weld/core/subscription_churn.sql) · [dbt](dbt/models/core/core_recurly__subscription_churn.sql) | churned subscriptions by reason, voluntary or involuntary | expired subscription |
| [`weld/core/recurring_revenue_lines.sql`](weld/core/recurring_revenue_lines.sql) · [dbt](dbt/models/core/core_recurly__recurring_revenue_lines.sql) | (input to the MRR models) | line item |

Nothing here has been run against a warehouse. Reconcile a closed month against
the Recurly UI before relying on the output (see [Reconciling](#reconciling)).

## How MRR is built

**From line items, not from subscriptions.** The `subscription` table is current
state: it says what a subscription costs today and nothing about last March.
`subscription_history` only holds the versions Weld has captured since that stream
was switched on. Line items are an immutable record of what was billed for which
service period, so they reproduce any month back to the start of the site.

1. **Recurring lines.** `recurring_revenue_lines` takes every invoiced line item
   with `origin` `plan` or `add_on` and a service period, on any invoice that is
   not voided. That includes the credit lines Recurly creates on a downgrade or a
   termination: a credit inherits the origin of the charge it reverses, and is
   negative, so it takes the unused part of the old plan back out. Trials, setup
   fees, one-time charges, carryforwards and manual credits do not count. Pending
   line items, not yet on an invoice, are left out.
2. **Monthly amount.** Each line is net of discounts, ex tax, and divided by the
   length of its service period in months. A period within 3 days of a whole
   number of months counts as exactly that many (28 to 31 days is 1 month, 365 is
   12), so annual and quarterly plans normalise cleanly. Anything else, typically
   a proration, counts as days / 30.4375.
3. **Snapshot.** An account's MRR for a month is the sum of the monthly amounts of
   every line whose service period covers the last day of that month (today, for
   the month in progress).
4. **Movements.** Each month is compared with the one before, per account:

| Movement | Rule | Sign |
|---|---|---|
| new | was 0, now above 0, never had MRR before | + |
| reactivation | was 0, now above 0, had MRR in an earlier month | + |
| expansion | was above 0, now higher | + |
| contraction | was above 0, now lower but above 0 | − |
| churn | was above 0, now 0 | − |

so `beginning_mrr + new + expansion + contraction + churned + reactivation =
ending_mrr` on every row, and
[`assert_recurly__mrr_movements_reconcile.sql`](dbt/tests/assert_recurly__mrr_movements_reconcile.sql)
checks it.

Movements are counted per **account**, Recurly's customer. An account replacing one
subscription with another is an expansion or a contraction, not a churn plus a new.
Recurly puts `subscription_id` on every line item, so for a per-subscription view,
group `recurring_revenue_lines` by it.

## Currency

**Recurly stores money in major units.** Its API returns amounts as decimals in
the line's currency: 19.99 means 19.99. Nothing is divided.

**The stream stores those decimals as 32-bit floats.** A float holds about seven
significant digits, so 19.99 can land as 19.9899997711. Staging rounds every
amount to 2 decimals, which restores the exact value for ordinary amounts. Above
roughly 100,000.00 on a single invoice or line, a float can no longer hold every
cent, and totals may be off by a cent or two. Reconcile large invoices against
Recurly if that matters for you.

**MRR is in the invoice currency, and currency is part of every grain.** A site
that bills in EUR and USD gets two rows per month in `mrr_movements`, one per
currency. Never sum `ending_mrr` across currencies. Recurly does not supply an
exchange rate on invoices, so join a daily or monthly FX table of your own to
`mrr_movements` on month and currency and convert there.

## Layers

```
raw.recurly.*          ELT output, untouched
  ↓
weld/staging/*.sql     4 thin wrappers: cast, rename, round floats, de-duplicate
  ↓
weld/core/*.sql        the reports: all the business logic lives here
  ↓
weld/analytics/*.sql   BI-facing contracts, deliberately thin
```

**Staging** does the dull work once: casts, renames, de-duplicates on the primary
key, rounds amounts and computes each line's net amount.

**Core** holds the MRR logic. This is the layer worth reviewing.

**Analytics** exists for indirection, not transformation. Dashboards bind to
`analytics.recurly.mrr_movements`, so core can be renamed or re-grained without
breaking anything downstream. All three are `SELECT *`, deliberately.

`dbt/` holds the same models with dbt refs, generated from the Weld versions, so
the two cannot disagree about the logic. See [dbt/README.md](dbt/README.md).

With [GitHub Sync](https://weld.app/docs/transformations/github-sync) a push deploys
all of them and Weld resolves the dependency order. Weld references map to folder
paths, so `{{staging.recurly.invoice}}` expects the model in a `staging > recurly`
folder. Mirror that structure in your synced repo, or adjust the refs.

## Required tables

| Model | Raw tables |
|---|---|
| recurring revenue lines | `invoice_line_item`, `invoice` |
| mrr by customer month | the above, plus `account` |
| mrr movements | the above |
| billing by month | `invoice` |
| subscription churn | `subscription`, `account`, plus the tables for recurring revenue lines |

`subscription_history` and `plan` are not needed.

## Churn reasons

The MRR bridge says how much MRR was lost; `subscription_churn` says why. It
takes every expired subscription and groups Recurly's `expiration_reason`:

| churn_type | expiration_reason |
|---|---|
| voluntary | canceled |
| involuntary | nonpayment (dunning gave up), tax location invalid |
| term_ended | fixed billing cycles ran out |
| trial_not_converted | a cardless trial or a gift ended without billing info |
| other | anything else, left in `expiration_reason` to map |

`mrr_at_expiry` is the subscription's MRR on its last day, built the same way as
the bridge. A canceled subscription still running to the end of its term is not
churned yet and is not in the model until it expires. The bridge counts
customers and this model counts subscriptions, so an account swapping one
subscription for another shows up here but not as churn in the bridge.

## Reconciling

- **MRR today.** For subscriptions in state `active`, take `subtotal` (plan and
  add-ons, before tax) and divide by the plan's billing interval in months
  (`plan.interval_length`, with `interval_unit` `months`; days for weekly plans).
  Sum per currency and compare with `ending_mrr` for the current month in
  `mrr_movements`. Coupons and renewals not yet invoiced explain most of any gap.
- **MRR history.** Compare a closed month with Recurly's subscription analytics.
  Differences usually come from how Recurly treats discounts, trials and usage
  add-ons; the rules used here are listed above.
- **Billing.** `billing_by_month.charge_total` should match Recurly's invoice
  export for the month, filtered to charge and legacy invoices that are not
  voided.
- [`assert_recurly__credit_invoices_are_not_positive.sql`](dbt/tests/assert_recurly__credit_invoices_are_not_positive.sql)
  checks the sign convention that netting credits against charges depends on.
  Run it first.

## Notes

- **The month in progress is provisional.** A renewal shows up when its invoice is
  created, and usage add-ons show up when they are invoiced. Until then the account
  looks churned or contracted for the current month. `is_current_month` flags those
  rows.
- **A mid-period plan change is approximate for one month.** Recurly prorates by
  the actual days in the billing period; normalising a prorated line by
  days / 30.4375 can leave the snapshot a few percent of that subscription's MRR
  off in the month of the change. It is exact again from the next renewal.
- **Refunds of plan charges lower MRR for the refunded period.** A refund credit
  keeps the `plan` origin, so a full refund removes that period from MRR. MRR is
  floored at 0 if credits in a month exceed charges.
- **Net amount is subtotal minus discount.** Recurly's own `amount` column is kept
  in staging, but MRR does not read it, so it does not matter whether your
  invoices are tax inclusive.
- **Churn is measured in months, not per renewal.** An account churns in the
  month its last recurring service period ends without a successor. MRR is not
  attributed to the month an invoice was created: a yearly plan counts one
  twelfth in every month it covers.
- **Failed invoices stay in billing.** They were billed; `failed_total` shows how
  much of a month's billing collection gave up on.

## Schema notes

Checked against both the public ERD and the schema Weld syncs; the tables and
columns used here match in both.

- **Amounts are 32-bit floats** in the stream, as described under Currency.
- **No exchange rate or base-currency amount** on invoices or line items, hence
  the currency section above.
- **`subscription_history` is an append-only capture** from the day the stream was
  enabled, not a back-filled history, which is why MRR is built from line items.

[Recurly API: line items](https://recurly.com/developers/api/v2021-02-25/index.html#tag/line_item) ·
[Invoices](https://recurly.com/developers/api/v2021-02-25/index.html#tag/invoice) ·
[Charges and credits](https://docs.recurly.com/docs/adjustments)
