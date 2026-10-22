# eSmiley templates

Food waste by day, area and registration point, in kilograms, money and CO2, for
kitchens weighing waste with eSmiley. BigQuery.

Weld connector: **eSmiley** ([docs](https://weld.app/docs/applications/esmiley)).

| Model | Answers | Grain |
|---|---|---|
| [`weld/core/food_waste_daily.sql`](weld/core/food_waste_daily.sql) · [dbt](dbt/models/core/core_esmiley__food_waste_daily.sql) | Waste weight, value and CO2 per registration point | registration date × account × registration point |
| [`weld/core/food_waste_by_area_month.sql`](weld/core/food_waste_by_area_month.sql) · [dbt](dbt/models/core/core_esmiley__food_waste_by_area_month.sql) | Monthly trend per area, share of total, change vs last month | month × account × area × currency |

`weld/core/registration_point_tree.sql` is a helper that walks each registration
point up to its top-level area (Kitchen, Buffet, Plate waste), so waste registered
at any level rolls up to the same area.

## Layers

```
raw.esmiley.*          ELT output, untouched
  ↓
weld/staging/*.sql     3 thin wrappers: cast, rename, drop deleted registrations, convert units
  ↓
weld/core/*.sql        the reports, all business logic
  ↓
weld/analytics/*.sql   BI-facing contracts, deliberately thin
```

`dbt/` holds the same models with dbt refs, generated from the Weld versions; see
[dbt/README.md](dbt/README.md). With
[GitHub Sync](https://weld.app/docs/transformations/github-sync),
`{{staging.esmiley.registration}}` expects the model in a `staging > esmiley` folder.

## Required tables

| Model | Raw tables |
|---|---|
| food waste daily | `registration`, `registration_point`, `account` |
| food waste by area month | as above |

## Units: check these first

eSmiley stores weight, cost and CO2 as integers and does not document the units in
a public API reference. Staging reads them as:

| Raw column | Read as | Converted to |
|---|---|---|
| `amount` | grams (or kilograms when `unit` is `kg`) | `waste_kg` |
| `cost` | minor currency units (cents, øre) of `currency` | `cost`, divided by 100 |
| `co2_per_kg` | grams of CO2e per kg of waste | `co2_kg` = `waste_kg` × factor / 1000 |

Pick one registration in the eSmiley app and compare weight, value and CO2 with
`staging.esmiley.registration` before using the numbers. The raw integers are kept
as `amount_raw`, `cost_raw` and `co2_per_kg_raw`, so a different reading is a
one-line change in staging.

## Schema notes

- **Full refresh every sync.** The connector re-reads all registrations since
  2020 on each run, so deletions in eSmiley disappear here too; deleted
  registrations that eSmiley still returns carry `deleted_at` and are dropped.
- **Dates are UTC.** `registration_date` is the UTC date of the registration
  time. For kitchens far from UTC, late-evening registrations can land on the
  next day.
- **No covers or guest counts.** eSmiley's waste-per-guest figures need guest
  numbers, which the connector does not sync. Join your own covers (from a POS or
  reservation system) on date and account to get waste per cover.

## Reconciling

Nothing here has been run against a live warehouse. After checking the units
above, compare one account's total kilograms for last month with the eSmiley
dashboard for the same period.

[eSmiley](https://www.esmiley.com/)
