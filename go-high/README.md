# HighLevel templates

Rebuilds the HighLevel numbers agencies and their clients ask for most: what is in the
pipeline right now, how well leads convert by month and source, and how much money came
in through HighLevel Payments. BigQuery.

Weld connector: **HighLevel** ([docs](https://weld.app/docs/applications/go-high)).
The integration id, and so the folder and namespace, is `go-high`.

| Model | Recreates | Grain |
|---|---|---|
| [`weld/core/pipeline_snapshot.sql`](weld/core/pipeline_snapshot.sql) · [dbt](dbt/models/core/core_go_high__pipeline_snapshot.sql) | Opportunities board: deals and value per stage | location × pipeline × stage × status (now) |
| [`weld/core/opportunity_outcomes_monthly.sql`](weld/core/opportunity_outcomes_monthly.sql) · [dbt](dbt/models/core/core_go_high__opportunity_outcomes_monthly.sql) | Opportunity and lead source reports: win rate and won value | created month × location × pipeline × source |
| [`weld/core/payments_daily.sql`](weld/core/payments_daily.sql) · [dbt](dbt/models/core/core_go_high__payments_daily.sql) | Payments > Transactions, summed | day × location × currency × source type × status |

## Layers

```
raw.go_high.*           ELT output, untouched
  ↓
weld/staging/*.sql      4 thin wrappers: cast, rename
  ↓
weld/core/*.sql         the reports
  ↓
weld/analytics/*.sql    BI-facing contracts, deliberately thin
```

`dbt/` holds the same models with dbt refs, generated from the Weld versions. See
[dbt/README.md](dbt/README.md).

With [GitHub Sync](https://weld.app/docs/transformations/github-sync) Weld references map
to folder paths, so `{{staging.go_high.opportunity}}` expects the model in a
`staging > go_high` folder. Mirror that structure in your synced repo, or adjust the refs.

## Required tables

| Model | Raw tables |
|---|---|
| pipeline snapshot | `opportunity`, `pipeline`, `pipeline_stage` |
| opportunity outcomes monthly | `opportunity`, `pipeline` |
| payments daily | `transaction` |

`pipeline_stage` is written by the `pipeline` stream.

## How the numbers are defined

- **The snapshot is now.** Opportunities are synced in full each run as they currently
  stand, with no stage history. The snapshot is the board at sync time; schedule a daily
  snapshot of it if you want a pipeline trend.
- **Closed deals keep their stage.** HighLevel leaves won, lost and abandoned deals on
  the stage they closed in, so `status` is part of the snapshot grain and open value is
  never mixed with closed value.
- **Outcomes are cohorted on created month.** A deal created in March and won in May is a
  March win. Recent months keep improving as open deals close.
- **Win rate is won / (won + lost).** Abandoned deals are excluded from it and counted on
  their own.
- **Payments keep status in the grain.** HighLevel's transaction status values depend on
  the payment provider and are not fully documented, so the model does not decide which
  ones mean money collected. Filter to your successful statuses (typically `succeeded`
  plus the refunded states) for revenue.
- **Refunds are dated on the original payment.** The transaction carries the refunded
  amount but no refund date.

## Schema notes

- **Location on transactions.** The transaction table has no `location_id` column. The
  connector fetches transactions per location, and HighLevel records that location in
  `alt_id` with `alt_type = 'location'`; staging surfaces it as `location_id`.
- **Amount units.** Check one transaction against Payments > Transactions in HighLevel
  to confirm amounts are in the unit you expect before relying on totals.
- **No stage history.** Without stage change events, time-in-stage and stage-to-stage
  conversion cannot be rebuilt. `avg_days_in_stage` is the age of current deals in their
  current stage.
- **Messages and conversations are not used.** The message table has no direction column
  for non-email channels, so inbound versus outbound volume cannot be reported reliably.
- Staging columns were checked against the published ERD and the connector's stream
  definitions; they agree for every table used here.

## Reconciling

Nothing here has been run against a warehouse. Before relying on it, compare
`pipeline_snapshot` for one pipeline with the Opportunities board (count and value per
stage, open deals only), and a closed month of `payments_daily` with Payments >
Transactions filtered to the same dates and location.

[HighLevel API documentation](https://marketplace.gohighlevel.com/docs/)
