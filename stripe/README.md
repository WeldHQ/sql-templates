# Stripe templates

SQL reports over Weld's Stripe connector. BigQuery.

| Model | Report | What it returns |
|---|---|---|
| [`weld/staging/subscriptions.sql`](weld/staging/subscriptions.sql) · [dbt](dbt/models/staging/stg_stripe__subscriptions.sql) | Get all subscriptions | Extracts a comprehensive overview of Stripe subscriptions. This helps in understanding the status and duration of various subscriptions tied to different customers. |
| [`weld/core/mrr_active_subscriptions.sql`](weld/core/mrr_active_subscriptions.sql) · [dbt](dbt/models/core/core_stripe__mrr_active_subscriptions.sql) | Identify active subscriptions and sum revenue | This SQL model fetches the monthly revenue per subscription and applies discounts to provide a net monthly amount. It then identifies if a subscription is active or canceled based on the status. |
| [`weld/core/mrr_normalization.sql`](weld/core/mrr_normalization.sql) · [dbt](dbt/models/core/core_stripe__mrr_normalization.sql) | Normalize to monthly revenue | This SQL model fetches the monthly subscription amounts, converts them to EUR using average monthly forex rates, and provides insights into revenue streams in a standardized currency. |
| [`weld/core/mrr_summary.sql`](weld/core/mrr_summary.sql) · [dbt](dbt/models/core/core_stripe__mrr_summary.sql) | Summarize Monthly Recurring Revenue (MRR) | This SQL model provides a comprehensive view of the Monthly Recurring Revenue (MRR) by categorizing the revenue into new MRR, contraction MRR, churn MRR, and expansion MRR. It also computes the net new MRR and total MRR over time. |
| [`weld/core/mrr_time_series.sql`](weld/core/mrr_time_series.sql) · [dbt](dbt/models/core/core_stripe__mrr_time_series.sql) | Create time series for each customer | This SQL model captures the monthly recurring revenue (MRR) trend for each customer, including the change in MRR, and provides a rank based on the MRR. It also considers the customer's subscription status and cancellation date. |
| [`weld/core/subscription_item.sql`](weld/core/subscription_item.sql) · [dbt](dbt/models/core/core_stripe__subscription_item.sql) | Get subscription plans | Pulls an exhaustive view of Stripe subscriptions, diving into associated items, the specifics of plans, discounts applied through coupons, and additional metrics like the amount discounted and subscription intervals. |

## Where these come from

These started as the templates in the weld.app template library. Each one was
published as a single query rather than a layered model set. Every query was
reviewed when it moved here and corrected where it was wrong; the corrections
are listed under Changes from the website version. The layout:

- Queries that hold report logic sit in `weld/core/`, each with a `SELECT *`
  passthrough in `weld/analytics/` for dashboards to bind to.
- Queries that other templates read as a `{{staging...}}` ref sit in
  `weld/staging/`, so those refs resolve.
- Most queries read the raw tables directly, so there is no staging layer of
  cast-and-rename wrappers like the one in [`shopify/`](../shopify/).
- None of them has been reconciled against the source system. Treat every model
  as a starting point and check the output before relying on it.
- `dbt/` holds the same SQL with `{{ source() }}` / `{{ ref() }}` refs. No dbt
  tests ship with these models.

## Changes from the website version

The six queries form one MRR chain, and on the website they pointed at a demo
folder (`{{stripe_demo.stripe_subscriptions}}` and so on). The refs now point at
the files here, in this order:

```
staging/subscriptions          <- raw.stripe.subscription
core/subscription_item         <- subscriptions + items, plans, discounts, coupons
core/mrr_normalization         <- subscription_item + raw.forex_eur.incremental
core/mrr_active_subscriptions  <- mrr_normalization
core/mrr_time_series           <- mrr_active_subscriptions
core/mrr_summary               <- mrr_time_series
```

`mrr_normalization` converts to EUR with an exchange-rate table read from
`raw.forex_eur.incremental` (columns `rate`, `currency`, `timestamp`), such as
Weld's Foreign Exchange connector with EUR as the base. Point it at your own
rates table if it lives elsewhere.

Corrected in review:

- `core/mrr_active_subscriptions` groups by its output columns by position. The website version grouped by unqualified names that several joined tables share, and by subscription status as well, which could give a customer two rows for one month and fan out the time series.
- `core/mrr_time_series` starts its calendar at the earliest subscription start month in the data. The website version truncated a string literal (`date_trunc('2021-01-01', month)`), which fails, and hardcoded 2021.

## Required tables

| Model | Raw tables |
|---|---|
| `staging/subscriptions` | `stripe.subscription` |
| `core/mrr_active_subscriptions` | none · reads `core.stripe.mrr_normalization` |
| `core/mrr_normalization` | `forex_eur.incremental` · reads `core.stripe.subscription_item` |
| `core/mrr_summary` | none · reads `core.stripe.mrr_time_series` |
| `core/mrr_time_series` | none · reads `core.stripe.mrr_active_subscriptions` |
| `core/subscription_item` | `stripe.coupon`, `stripe.plan`, `stripe.subscription_discount`, `stripe.subscription_item` · reads `staging.stripe.subscriptions` |

## Models

### Get all subscriptions

`weld/staging/subscriptions.sql`

This SQL model enables businesses to quickly gather a holistic view of their Stripe
subscriptions. By listing out essential details like subscription ID, associated
customer ID, start date, potential cancellation date, and the subscription's status,
businesses can efficiently manage and track their billing processes. This insight is
crucial for maintaining customer relationships and ensuring a smooth subscription
experience for users.

### Identify active subscriptions and sum revenue

`weld/core/mrr_active_subscriptions.sql`

This model provides insights into the net revenue streams from each subscription
after considering discounts. By segregating active and cancelled subscriptions,
businesses can assess their revenue health more effectively and make informed
financial decisions.

### Normalize to monthly revenue

`weld/core/mrr_normalization.sql`

This model helps in getting a clear view of revenue when dealing with multiple
currencies. By converting all subscription amounts to EUR, you can analyze your
revenue without the complexity of currency fluctuations. It uses average monthly
forex rates for conversions and provides a monthly breakdown of the subscription
amounts.

### Summarize Monthly Recurring Revenue (MRR)

`weld/core/mrr_summary.sql`

By understanding the different components of MRR, businesses can pinpoint areas of
growth or potential issues. The breakdown helps in identifying trends in customer
acquisition, churn, or expansion and provides a clear picture of the business health
over time.

### Create time series for each customer

`weld/core/mrr_time_series.sql`

By using this model, businesses can gain insights into their customer's MRR
progression, helping in understanding the customer's lifetime value, churn patterns,
and overall business health. The time series analysis also assists in predicting
future revenue patterns and making informed business decisions.

### Get subscription plans

`weld/core/subscription_item.sql`

This SQL model provides businesses with intricate details about their Stripe
subscriptions. Beyond just fetching the status and duration of each subscription,
this model delves into the associated items and plans, detailing specifics like
pricing and intervals. Furthermore, it fetches discount details applied through
coupons, a crucial insight for understanding customer incentives. It also provides
an additional metric - if the subscription was deleted within the same month of its
start date.
