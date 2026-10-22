# Salesforce templates

SQL reports over Weld's Salesforce connector. BigQuery.

| Model | Report | What it returns |
|---|---|---|
| [`weld/core/aggregated_daily_sales_report.sql`](weld/core/aggregated_daily_sales_report.sql) · [dbt](dbt/models/core/core_salesforce__aggregated_daily_sales_report.sql) | Aggregated Daily Salesforce Report | Extracts a day-by-day breakdown of CRM activities on Salesforce, covering tasks, events, lead generation, and opportunities. It integrates various data points to deliver insights such as leads created, tasks completed, events held, and opportunity metrics. |

## Where these come from

These are the templates from the weld.app template library, moved here
unchanged apart from the notes below. Each one was published as a single query
rather than a layered model set, so:

- Queries that hold report logic sit in `weld/core/`, each with a `SELECT *`
  passthrough in `weld/analytics/` for dashboards to bind to.
- Most queries read the raw tables directly, so there is no staging layer of
  cast-and-rename wrappers like the one in [`shopify/`](../shopify/).
- None of them has been reconciled against the source system. Treat every model
  as a starting point and check the output before relying on it.
- `dbt/` holds the same SQL with `{{ source() }}` / `{{ ref() }}` refs. No dbt
  tests ship with these models.

## Required tables

| Model | Raw tables |
|---|---|
| `core/aggregated_daily_sales_report` | `salesforce.event`, `salesforce.lead`, `salesforce.opportunity`, `salesforce.task` |

## Models

### Aggregated Daily Salesforce Report

`weld/core/aggregated_daily_sales_report.sql`

This SQL model offers a granular daily report of CRM activity on Salesforce. It
integrates insights from tasks, events, leads, and opportunities to provide a
holistic view of the business pipeline. The model captures metrics like tasks
completed, events organized, leads generated and converted, opportunities created
and closed, and the respective amounts associated with those opportunities.

## Known issues

Found while moving the templates here. The SQL is kept as published; fix these
before running the affected models.

- `core/aggregated_daily_sales_report`: the date spine runs to 2099-12-31, producing tens of thousands of empty future rows. `COALESCE(DATE_TRUNC(activity_date, DAY), DATE_TRUNC(activity_date_time, DAY))` mixes DATE and TIMESTAMP, which fails without a cast (likely).
