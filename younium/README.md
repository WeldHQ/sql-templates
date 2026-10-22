# Younium templates

Rebuilds Younium's committed MRR (CMRR) movements and its CMRR per customer in your
warehouse. BigQuery, Younium base currency.

Weld connector: **Younium**
([docs](https://weld.app/docs/applications/younium)).

| Model | Recreates | Grain |
|---|---|---|
| [`weld/core/mrr_movements.sql`](weld/core/mrr_movements.sql) · [dbt](dbt/models/core/core_younium__mrr_movements.sql) | CMRR movements: the monthly bridge from opening to closing CMRR | month |
| [`weld/core/subscription_mrr_movements.sql`](weld/core/subscription_mrr_movements.sql) · [dbt](dbt/models/core/core_younium__subscription_mrr_movements.sql) | The same movements per subscription, for drill-down | month × order number |
| [`weld/core/account_cmrr.sql`](weld/core/account_cmrr.sql) · [dbt](dbt/models/core/core_younium__account_cmrr.sql) | Current CMRR, CARR, ACV and TCV per account | account (current snapshot) |

## Built from bookings, not re-derived from charges

Every time a subscription is created, changed, renewed or cancelled, Younium writes a
**booking**: the change in CMRR, ACV and TCV that event caused, dated by when it takes
effect, and classified by Younium as `NewCustomer`, `Expansion`, `Contraction`,
`CustomerChurn`, `Reactivate`, `NoChange` or `SplitOrder`. That classification is
exactly an MRR movements breakdown, computed by Younium with its own rules for
renewals, price adjustments and split orders. These templates sum bookings rather
than re-deriving movements from subscription charges, so the result follows
Younium's definitions.

```
opening_cmrr
  + new_customer_cmrr + expansion_cmrr + reactivation_cmrr
  + contraction_cmrr + churned_cmrr        (negative)
  + other_cmrr                             (NoChange, SplitOrder, unclassified)
= closing_cmrr
```

`closing_cmrr` is the running sum of `net_cmrr_change` since the first booking.

**Sign convention, to verify on your data.** Younium's API documents bookings as
amounts per booking but does not spell out their sign. The bridge assumes they are
signed changes: contraction and churn negative, the rest positive.
`tests/assert_movement_signs_match_classification.sql` checks this on your data; if
it returns rows, look at those bookings in Younium before using the bridge.

## Units and currency

- **Major units.** Younium returns amounts as decimals (`1250.00`), not cents. No
  unit conversion is applied.
- **Base currency for everything that adds up.** Each booking carries its CMRR change
  in the order's currency and converted to the Younium base currency. The bridge and
  the drill-down use the base currency amount, converted by Younium at booking time,
  so orders in different currencies add up. `base_currency` is read from the account
  table. The order-currency change is kept in the drill-down as
  `net_cmrr_change_order_currency`, with `order_currency`, for anyone reporting per
  billing currency; do not sum it across orders with different currencies.
- **CMRR is committed MRR**: recurring charges on signed orders, including ones that
  start in the future, as Younium defines it. It is not invoiced revenue.

## Layers

```
raw.younium.*           ELT output, untouched
  ↓
weld/staging/*.sql      3 thin wrappers: cast, rename, de-duplicate
  ↓
weld/core/*.sql         the reports: all the business logic lives here
  ↓
weld/analytics/*.sql    BI-facing contracts, deliberately thin
```

Analytics models are `SELECT *` over core. Dashboards bind to them so core can change
without breaking anything downstream.

`dbt/` holds the same models with dbt refs, generated from the Weld versions. See
[dbt/README.md](dbt/README.md).

With [GitHub Sync](https://weld.app/docs/transformations/github-sync), Weld references
map to folder paths, so `{{staging.younium.booking}}` expects the model in a
`staging > younium` folder.

## Required tables

| Model | Raw tables |
|---|---|
| mrr movements | `booking`, `subscription`, `account` |
| subscription mrr movements | `booking`, `subscription` |
| account cmrr | `account` |

## Notes

- **Months are calendar months of the booking's effective date**, in UTC. A change
  signed in March that takes effect in April lands in April. Use `created_at` in
  `staging.younium.booking` instead if you report bookings by signing date.
- **Closing CMRR needs the full booking history.** By default the connector's first
  sync fetches bookings modified in the last three years (or since the start date
  set on the connector). Bookings older than that and never touched since are not
  synced, so the bridge starts short and `closing_cmrr` falls below real CMRR by
  whatever they added up to. Set an early start date on the connector to avoid this.
  The same modified-date window applies to `account` and `subscription`, so an
  account untouched for longer than the window is missing from `account_cmrr` too.
  Compare `closing_cmrr` with `younium_current_cmrr` (the live total over all
  accounts) in the current month; the gap is the opening balance you are missing.
- **Customer-level movements are not available.** Bookings link to an order, and the
  synced subscription table does not include the order's account, so the drill-down
  stops at subscription. `account_cmrr` gives current CMRR per account, but not its
  history.
- **Order counts, not customer counts.** `orders_from_new_customers`,
  `orders_churned` and `orders_reactivated` count orders with at least one booking of
  that class in the month. A customer with two orders counts twice.
- **What was not built, and why.**
  - The connector also syncs `daily_charge_metric` and `daily_order_metric_per_product`.
    They come from Younium's metrics calculator, which prices a single catalog
    product or charge over a one-day term. They describe the price list, not what
    customers are committed to, so they are not used for MRR.
  - A month-end MRR schedule from `subscription_product_charge` (effective dates and
    `recurring_monthly_amount_base`) is possible in principle, but it needs to know
    how Younium keeps superseded charge versions in the subscription payload, and it
    cannot be tied to accounts. Bookings answer the same question with Younium's own
    classification, so the templates use those.

## Schema notes

- `subscription`: Younium's API returns the order's account, but the connector's
  `subscription` table does not include it (neither in the ERD nor in the connector
  definition). This is why there is no customer-level movement model.
- `booking`: the API's `bookingChangeType` object is not on the table; `change_type`
  and the classification columns are.
- Date columns the ERD lists as `date` are loaded as timestamps; staging casts them
  explicitly.

## Reconciling

Nothing here has been run against a warehouse. Before relying on the output,
reconcile against Younium: sum the bookings for one month in Younium's bookings view
by classification and compare with `mrr_movements`, and compare `account_cmrr` for a
few accounts with the CMRR shown on the account in Younium. The dbt tests check
internal consistency and the sign convention only.

Younium references:
[Developer documentation](https://developer.younium.com/) ·
[Bookings API](https://developer.younium.com/api-s/api-2.1/bookings) ·
[Bookings guide](https://support.younium.com/hc/en-us/articles/360032279691-Bookings-Guide) ·
[Metrics guide](https://support.younium.com/hc/en-us/articles/360031863792-Metrics-Guide)
