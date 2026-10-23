# Salesforce templates

SQL reports over Weld's Salesforce connector. BigQuery.

| Model | Report | What it returns |
|---|---|---|
| [`weld/core/aggregated_daily_sales_report.sql`](weld/core/aggregated_daily_sales_report.sql) · [dbt](dbt/models/core/core_salesforce__aggregated_daily_sales_report.sql) | Aggregated Daily Salesforce Report | One row per day: leads created and converted, closed tasks, events, and opportunities created, won, lost and in open pipeline, with their amounts. |

## Where these come from

These started as the templates in the weld.app template library. Each one was
published as a single query rather than a layered model set. Every query was
reviewed when it moved here and corrected where it was wrong; the corrections
are listed under Changes from the website version. The layout:

- Queries that hold report logic sit in `weld/core/`, each with a `SELECT *`
  passthrough in `weld/analytics/` for dashboards to bind to.
- Most queries read the raw tables directly, so there is no staging layer of
  cast-and-rename wrappers like the one in [`shopify/`](../shopify/).
- None of them has been reconciled against the source system. Treat every model
  as a starting point and check the output before relying on it.
- `dbt/` holds the same SQL with `{{ source() }}` / `{{ ref() }}` refs. No dbt
  tests ship with these models.

## Changes from the website version

Corrected in review:

- `core/aggregated_daily_sales_report` was rewritten from the raw tables. The calendar now runs from the first day with activity to today, or to the latest expected close date of open pipeline, instead of to 2099-12-31. Every date is taken with `DATE()` from the timestamps Weld lands, which removes the DATE/TIMESTAMP mix that failed. Deleted records are left out, `tasks_completed` counts closed tasks only, and quiet days show zeros.

## Required tables

| Model | Raw tables |
|---|---|
| `core/aggregated_daily_sales_report` | `salesforce.event`, `salesforce.lead`, `salesforce.opportunity`, `salesforce.task` |

## Models

### Aggregated Daily Salesforce Report

`weld/core/aggregated_daily_sales_report.sql`

A daily view of CRM activity in Salesforce. Each metric lands on the day it
happened: leads on their created and converted dates, closed tasks on their
activity date, events on their start, new opportunities on their created date,
and won, lost and open pipeline amounts on their close date. Every day from the
first activity to today has a row, so gaps show as zeros.
