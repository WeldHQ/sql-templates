# Claimlane templates

Claim and return volume, refunds by product and reason, and supplier decisions on
retailer claims, from Weld's Claimlane connector. BigQuery, in each ticket's shop
currency.

| Model | Answers | Grain |
|---|---|---|
| [`weld/core/b2c_claim_lines.sql`](weld/core/b2c_claim_lines.sql) · [dbt](dbt/models/core/core_claimlane__b2c_claim_lines.sql) | Every claimed product, its reason, what it was worth and what was refunded | consumer ticket × product line |
| [`weld/core/b2c_claims_by_month.sql`](weld/core/b2c_claims_by_month.sql) · [dbt](dbt/models/core/core_claimlane__b2c_claims_by_month.sql) | Claim volume by type, how claims were settled, refunds over time | month × organisation × ticket type × currency |
| [`weld/core/b2c_claims_by_product.sql`](weld/core/b2c_claims_by_product.sql) · [dbt](dbt/models/core/core_claimlane__b2c_claims_by_product.sql) | Which products come back, why, and what they cost | organisation × currency × SKU × reason |
| [`weld/core/b2b_claim_lines.sql`](weld/core/b2b_claim_lines.sql) · [dbt](dbt/models/core/core_claimlane__b2b_claim_lines.sql) | Every retailer claim line and the supplier's decision on it | B2B claim × product line |
| [`weld/core/b2b_claims_by_month.sql`](weld/core/b2b_claims_by_month.sql) · [dbt](dbt/models/core/core_claimlane__b2b_claims_by_month.sql) | Retailer claims and acceptance rate per brand over time | month × brand × claim type |

## Read this first: what this connector cannot do

**1. There is no resolution time.** The connector syncs when a consumer ticket was
created, but no status and no closed or resolved timestamp. Average handling time,
SLA breaches and "open tickets right now" for consumer claims cannot be built
honestly from this data. Every B2C report here is on the date the claim came in.

B2B claims are a little better: each product line carries the supplier's decision,
and the claim carries `updated_at`. `b2b_claim_lines` reports `days_to_last_update`
for decided lines, but that is the time to the claim's latest edit of any kind, so
it is an upper bound on the decision time, never the decision time itself.

**2. No return rate without your sales data.** Claimlane knows the products that
were claimed, not the ones that were sold. `b2c_claims_by_product` gives claimed
units per SKU; divide by units sold from your shop platform on the same SKU to get
a rate.

**3. Refunds land on the claim's month.** Because there is no refund date, a claim
created in March and refunded in April counts its refund in March. Finance totals
by payment date come from your payment provider, not from here.

**4. B2B claims have no price.** The connector syncs quantities and decisions on
retailer claim lines but no unit price, so B2B claims are counted, not valued.

## Layers

```
raw.claimlane.*          ELT output, untouched
  ↓
weld/staging/*.sql       5 thin wrappers: cast, rename, personal data left out
  ↓
weld/core/*.sql          the reports, all the business logic lives here
  ↓
weld/analytics/*.sql     BI-facing contracts, deliberately thin
```

**Staging** casts, renames and blanks to NULL. It also leaves out the consumer's
name, email, phone, street address and refund bank details (IBAN, account number,
sort code), which sit on the raw consumer ticket. Nothing downstream needs them, and
leaving them out of staging means no dashboard can pick them up by accident.

**Core** holds the line-level joins, the B2B decision grouping, the month spines and
the rates. `b2c_claim_lines` and `b2b_claim_lines` are line grain and the other three
read them. This is the layer worth reviewing.

**Analytics** exists for indirection, not transformation. Bind dashboards and
reverse-ETL syncs to `analytics.claimlane.b2c_claims_by_month` so core stays free to
be renamed or re-grained. All five are `SELECT *`: that is the point, not an
oversight.

With [GitHub Sync](https://weld.app/docs/transformations/github-sync) a push deploys
all of them and Weld resolves the dependency order. Weld references map to folder
paths, so `{{staging.claimlane.b2c_ticket}}` expects the model in a
`staging > claimlane` folder. Mirror that structure in your synced repo, or adjust
the refs.

## Required tables

| Model | Raw tables |
|---|---|
| B2C claim lines | `b2c_ticket`, `b2c_ticket_product`, `b2c_ticket_product_refund` |
| B2C claims by month | the same |
| B2C claims by product | the same |
| B2B claim lines | `b2b_ticket`, `b2b_ticket_product` |
| B2B claims by month | the same |

The product and refund tables land automatically with their ticket stream: they are
the nested arrays of each ticket. Sync only the side you use; the B2C and B2B models
do not depend on each other.

**B2B tickets are read per supplier.** The connector fetches retailer claims for the
supplier organisations selected on the connection (all of them when none is
selected). A key that sees no supplier organisations syncs no B2B tickets.

Deliberately not modelled: the six `raw_*` export tables, whose columns are named by
each account's own Claimlane configuration so no fixed model can read them; the tag,
property, part and identification sub-tables, which are configuration-specific
labels; and `retailer`, `supplier` and `supplier_brand`, because the ticket tables
already carry the brand and retailer names and no report needs more.

## What b2c_claims_by_month returns

One row per month, organisation, ticket type (`return`, `claim`, `damagedInTransit`,
`missingItem`, `wrongItem` and the rest of Claimlane's types) and currency.

`tickets` counts consumer tickets from the ticket table, so a ticket with three
products is one ticket. How they were settled is split by Claimlane's return type:
`refund_tickets`, `exchange_tickets`, `store_credit_tickets` and
`keep_product_tickets`. `automated_tickets` and `automation_rate` show how many were
handled by Claimlane's return automation without an agent.

On the money side, `claimed_value` is what the claimed goods were sold for (quantity
× unit price) and `refunded_amount` is what was actually refunded against those
lines. `refund_rate_of_claimed_value` is the ratio of the two sums: below 1 when
claims end in exchanges, store credit, partial refunds or rejection.

## Schema notes

- **The product line key is ticket and position.** Some schema listings show an
  `id` column as the key of `b2c_ticket_product`. The connector keys product lines
  on `ticket_id` plus `index`, and the refund table points back with `ticket_id`
  plus `product_index`. The models join on those.
- **Refund currency is not stated.** Claimlane records no currency on a refund. The
  models treat refunds as being in the ticket's `currency`, the shop currency the
  order was placed in. For a shop selling in several presentment currencies, check
  one refund against your payment provider.
- **`return_price` is passed through, not used.** Claimlane documents it only as a
  number with its own currency; it is most likely the return shipping fee charged
  to the shopper, so check a few tickets before using it. It is on the first line of each ticket in `b2c_claim_lines` so
  summing it counts each ticket once.
- **Deleted tickets stay.** Claimlane's API does not report deletions, so a deleted
  ticket remains in the warehouse until the table is fully resynced.

## Notes

- **B2B decisions are grouped.** `acceptedCredit`, `acceptedCreditAndRecycle`,
  `acceptedReturn`, `acceptedReturnToSupplier` and `acceptedNoClaim` are `accepted`;
  `declined` is `declined`; `notHandled` is `open`; anything else is `other`.
  `acceptance_rate` divides accepted lines by decided lines (accepted + declined), so
  open lines in recent months do not look like rejections.
  [`assert_b2b_statuses_are_classified`](dbt/tests/assert_b2b_statuses_are_classified.sql)
  lists any status Claimlane adds later.
- **Rates are ratios of sums**, so a large order weighs what it is worth. Never
  average the rate columns across rows.
- **The monthly models are built on spines**, so a month with no claims returns
  zeros instead of disappearing from a trend line.
- **Multi-account ready.** Every staging model emits a `claimlane_account` label and
  it is part of every join key and grain. To add a second Claimlane connection,
  `UNION ALL` a second block in each staging model with a different label, and
  change nothing else.
- **Nothing here has been run against a warehouse.** Reconcile one month's ticket
  count per type against Claimlane's own overview, and a handful of refunds against
  your shop or payment provider, before relying on the output.

[Claimlane connector docs](https://weld.app/docs/applications/claimlane) ·
[Claimlane API reference](https://server-claimlane.claimlane.com/api-docs/)
