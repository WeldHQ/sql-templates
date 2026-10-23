# Grin templates

Influencer campaign reporting from Weld's Grin connector: the creator funnel,
content and reach, affiliate and discount-code sales, and what each campaign cost.
BigQuery.

| Model | Answers | Grain |
|---|---|---|
| [`weld/core/campaign_performance.sql`](weld/core/campaign_performance.sql) · [dbt](dbt/models/core/core_grin__campaign_performance.sql) | Funnel, content, sales and cost per campaign | campaign |
| [`weld/core/creator_campaign_performance.sql`](weld/core/creator_campaign_performance.sql) · [dbt](dbt/models/core/core_grin__creator_campaign_performance.sql) | What each creator delivered, sold, earned and was sent | campaign × creator |
| [`weld/core/conversions_by_day.sql`](weld/core/conversions_by_day.sql) · [dbt](dbt/models/core/core_grin__conversions_by_day.sql) | Attributed orders, revenue and commission over time | day × campaign × conversion type × currency |

## Read this first: what this connector cannot do

**1. Three money columns, three currencies.** Conversion revenue and commission
come in your store's currency (`currency` on the row). Payables come with Grin's own
US dollar conversion, which these models use. Product seeding cost is in whatever
currency the product costs were entered in, and the connector does not say which.
`campaign_performance` therefore only computes `revenue_per_payable_usd` when the
campaign's revenue is in USD, and leaves seeding cost out of every ratio. Convert
with your own rates if you need a single ROI number.

**2. Content stats are current, not historical.** Grin overwrites a post's
impressions, reach and engagements as it re-polls the network. There is no
"performance after 7 days"; an old campaign's reach keeps growing for as long as
Grin keeps collecting. If you need a fixed reporting window, materialise
`creator_campaign_performance` on a schedule and keep the snapshots.

**3. Seeding cost uses today's product cost.** Product and variant costs are current
values. Grin records no quantity on a product selection item, so each item counts
as one unit.

**4. Campaigns, not Activations.** Grin has two programme models. These templates
cover Campaigns, whose conversions, payables, content and proposals the connector
syncs per campaign. Activations are synced too (`activation`, `activation_member`,
`activation_brief`, and the account-wide `conversion` and `payable` tables carry an
`activation_id`), but conversions there have no campaign id, so they are not in
these models.

## Layers

```
raw.grin.*              ELT output, untouched
  ↓
weld/staging/*.sql      11 thin wrappers: cast, rename, dedupe
  ↓
weld/core/*.sql         the reports, all the business logic lives here
  ↓
weld/analytics/*.sql    BI-facing contracts, deliberately thin
```

**Staging** casts, renames and dedupes on each table's id. Contact staging keeps
only the creator's name, follower reach and stage; email, phone and address stay in
raw.

**Core** aggregates every source to campaign × creator before joining, so revenue
is never multiplied by the number of posts. `campaign_performance` rolls that model
up, so the two cannot disagree.

**Analytics** exists for indirection, not transformation. All three are `SELECT *`
on purpose.

With [GitHub Sync](https://weld.app/docs/transformations/github-sync) a push deploys
all of them and Weld resolves the dependency order. Weld references map to folder
paths, so `{{staging.grin.campaign}}` expects the model in a `staging > grin`
folder. Mirror that structure in your synced repo, or adjust the refs.

## Required tables

| Model | Raw tables |
|---|---|
| creator campaign performance | `campaign`, `proposal`, `content`, `content_stat`, `campaign_conversion`, `campaign_payable`, `contact_order`, `product_selection_item`, `product`, `product_variant`, `contact` |
| campaign performance | the same |
| conversions by day | `campaign_conversion`, `campaign` |

**Watch your Grin API quota.** Grin limits API requests per month, and
`campaign_conversion`, `campaign_payable` and `campaign_content` are synced once per
campaign on every sync. On an account with many campaigns, sync these
streams less often rather than switching them off. Do not enable `contact_campaign`
on a large account: it is read once per contact, and these models do not need it.

## What campaign_performance returns

One row per campaign, including campaigns with no activity yet.

- **Funnel:** `creators_proposed`, `creators_accepted`, `creators_declined`,
  `creators_completed`, `creators_posted`, `creators_with_sales`, and
  `agreed_fees` (the sum of accepted proposal prices).
- **Content:** `posts`, `stories`, `impressions`, `reach`, `views`,
  `engagements`, `imv` (Grin's media value estimate) and
  `engagement_rate_by_reach`, a ratio of sums.
- **Sales:** `conversions`, `voided_conversions`, `revenue`, `commission`,
  `average_order_value`, with `currency` (NULL when mixed) and
  `revenue_currencies`.
- **Cost:** `payables_usd` (owed to creators, voids excluded),
  `payables_in_payment_usd` (already in a payment run), cost per engagement and
  per thousand impressions, and the seeding columns: orders, units, product cost,
  shipping cost and retail value.

## Notes

- **Voided conversions are excluded from revenue** and counted separately. Voids
  land on the day of the conversion, not the day of the void, so the daily series
  reconciles to the campaign totals but a closed month can still move.
- **Creators count on any activity.** A creator appears on a campaign if they have
  a proposal, content, a conversion, a payable or a seeding order there. Someone who
  earns commission on an old code without a proposal is not dropped.
- **Days are cut in UTC.** Change the `'UTC'` literal in `conversions_by_day` to
  your reporting zone.
- **Multi-account ready.** Every staging model emits a `grin_account` label and it
  is part of every join key. To add a Grin account, `UNION ALL` a second block in
  each staging model with a different label, and change nothing else.
- **Not run against a warehouse.** These models were checked for syntax and schema,
  not executed. Reconcile one campaign's conversions, revenue and content count
  against its page in Grin before relying on the output.

[Grin connector docs](https://weld.app/docs/applications/grin) ·
[Grin API reference](https://api.grin.co/) · [Grin help centre](https://help.grin.co/)
