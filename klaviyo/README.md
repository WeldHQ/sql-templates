# Klaviyo templates

SQL reports over Weld's Klaviyo connector. BigQuery.

| Model | Report | What it returns |
|---|---|---|
| [`weld/staging/email_events.sql`](weld/staging/email_events.sql) · [dbt](dbt/models/staging/stg_klaviyo__email_events.sql) | Email Events | Retrieves various event details from the Klaviyo integration, including the event ID, timestamp, event name, custom properties, Klaviyo properties, UUID, person ID, metric ID, campaign ID, flow ID, flow, attributed event ID, message ID, send cohort, send timestamp, and order ID (if the event name is "Placed Order"). The results are ordered by the event timestamp in descending order. |
| [`weld/core/events_flow_campaign_report.sql`](weld/core/events_flow_campaign_report.sql) · [dbt](dbt/models/core/core_klaviyo__events_flow_campaign_report.sql) | Events Flow Campaign Report | Retrieves data from the Klaviyo integration to generate an Events Flow Campaign Report. It combines information from the events, campaign, and flow tables to provide details such as event timestamps, event names, custom properties, Klaviyo properties, metric IDs, campaign IDs, person IDs, flow IDs, attributed event IDs, message IDs, send cohorts, send timestamps, order IDs, flow names, flow statuses, campaign subjects, and campaign sent timestamps. The final result is sorted in descending order based on the event timestamps. |
| [`weld/core/monthly_campaign_status_breakdown_by_list.sql`](weld/core/monthly_campaign_status_breakdown_by_list.sql) · [dbt](dbt/models/core/core_klaviyo__monthly_campaign_status_breakdown_by_list.sql) | Monthly Campaign Status Breakdown by List | Generates a monthly breakdown of campaign status for a specific integration with Klaviyo. It retrieves the number of campaigns, the number of campaigns sent, the number of campaigns in draft and scheduled status, as well as other campaign statuses if needed. Additionally, it includes the list name, the number of lists used, and the last sent date. The results are grouped by campaign month, list name, and template name, and ordered in descending order of the campaign month. |
| [`weld/core/monthly_flow_events.sql`](weld/core/monthly_flow_events.sql) · [dbt](dbt/models/core/core_klaviyo__monthly_flow_events.sql) | Monthly Flow Events | Generates a report of monthly flow events from the Klaviyo integration. It calculates the total number of events triggered and the number of distinct persons triggered for each flow in a given month. The result includes the month, flow ID, flow name, flow status, trigger type, trigger filter, customer filter, total events triggered, and distinct persons triggered, ordered by month and flow name. |
| [`weld/core/monthly_user_engagement_per_campaign.sql`](weld/core/monthly_user_engagement_per_campaign.sql) · [dbt](dbt/models/core/core_klaviyo__monthly_user_engagement_per_campaign.sql) | Monthly User Engagement per Campaign | Calculates the monthly user engagement per campaign using data from Klaviyo integration. It extracts the year, month, campaign ID, event name, and counts the number of unique persons for specific events. It then aggregates the counts for each event type and campaign, grouping them by year, month, campaign ID, and campaign name. The final result is ordered by year, month, and campaign name. |

## Where these come from

These are the templates from the weld.app template library, moved here
unchanged apart from the notes below. Each one was published as a single query
rather than a layered model set, so:

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

## Required tables

| Model | Raw tables |
|---|---|
| `staging/email_events` | `klaviyo_import.event` |
| `core/events_flow_campaign_report` | `klaviyo.campaign`, `klaviyo.flow` · reads `staging.klaviyo.email_events` |
| `core/monthly_campaign_status_breakdown_by_list` | `klaviyo.campaign_list`, `klaviyo.campaign`, `klaviyo.email_template`, `klaviyo.list` |
| `core/monthly_flow_events` | `klaviyo.event`, `klaviyo.flow` |
| `core/monthly_user_engagement_per_campaign` | `klaviyo.campaign`, `klaviyo.event` |

## Models

### Email Events

`weld/staging/email_events.sql`

The SQL template named "email_events" is designed to work with the Klaviyo
integration. This SQL model retrieves various event-related information from the
Klaviyo platform. The selected fields include event ID, event timestamp, event name,
custom properties, Klaviyo properties, UUID, person ID, metric ID, campaign ID, flow
ID, flow, attributed event ID, message ID, send cohort, send timestamp, and order
ID.

### Events Flow Campaign Report

`weld/core/events_flow_campaign_report.sql`

The Events Flow Campaign Report SQL template is designed to retrieve information
from the Klaviyo integration database. This SQL model combines data from three
different tables: events, campaign, and flow.

### Monthly Campaign Status Breakdown by List

`weld/core/monthly_campaign_status_breakdown_by_list.sql`

The Monthly Campaign Status Breakdown by List SQL template is designed to provide
insights into the performance of campaigns in Klaviyo, a popular email marketing
integration. This SQL query retrieves data on various campaign statuses, such as
sent, draft, and scheduled, and breaks them down by month and list name.

### Monthly Flow Events

`weld/core/monthly_flow_events.sql`

The Monthly Flow Events SQL template is designed to provide insights into the flow
events triggered within a given month using Klaviyo integration. This SQL model
calculates the total number of events triggered and the number of distinct persons
triggered for each flow within a specific month.

### Monthly User Engagement per Campaign

`weld/core/monthly_user_engagement_per_campaign.sql`

The SQL template "Monthly User Engagement per Campaign" is designed to analyze user
engagement metrics for different campaigns in a monthly timeframe. This template is
integrated with Klaviyo, a popular email marketing platform.

## Known issues

Found while moving the templates here. The SQL is kept as published; fix these
before running the affected models.

- `core/events_flow_campaign_report`: `from select distinct event_name from ...` is a syntax error; it should read `from {{staging.klaviyo.email_events}}`. It also selects `flow.flow_status`, which the CTE names `status_flow_status`.
- `staging/email_events`: `'$.flow'` and `'$.event_id'` are read without stripping `$` from the Klaviyo keys, unlike the neighbouring lines, so they probably return NULL (likely).
