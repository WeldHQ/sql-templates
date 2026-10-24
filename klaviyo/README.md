# Klaviyo templates

SQL reports over Weld's Klaviyo connector. BigQuery.

| Model | Report | What it returns |
|---|---|---|
| [`weld/staging/email_events.sql`](weld/staging/email_events.sql) · [dbt](dbt/models/staging/stg_klaviyo__email_events.sql) | Email Events | Retrieves various event details from the Klaviyo integration, including the event ID, timestamp, event name, custom properties, Klaviyo properties, UUID, person ID, metric ID, campaign ID, flow ID, flow, attributed event ID, message ID, send cohort, and order ID (if the event name is "Placed Order"). The results are ordered by the event timestamp in descending order. |
| [`weld/core/events_flow_campaign_report.sql`](weld/core/events_flow_campaign_report.sql) · [dbt](dbt/models/core/core_klaviyo__events_flow_campaign_report.sql) | Events Flow Campaign Report | Retrieves data from the Klaviyo integration to generate an Events Flow Campaign Report. It combines information from the events, campaign, and flow tables to provide details such as event timestamps, event names, custom properties, Klaviyo properties, metric IDs, campaign IDs, person IDs, flow IDs, attributed event IDs, message IDs, send cohorts, order IDs, flow names, flow statuses, campaign names, and campaign send times. The final result is sorted in descending order based on the event timestamps. |
| [`weld/core/monthly_campaign_status_breakdown_by_list.sql`](weld/core/monthly_campaign_status_breakdown_by_list.sql) · [dbt](dbt/models/core/core_klaviyo__monthly_campaign_status_breakdown_by_list.sql) | Monthly Campaign Status Breakdown by List | Generates a monthly breakdown of campaign status for a specific integration with Klaviyo. It retrieves the number of campaigns, the number of campaigns sent, the number of campaigns in draft and scheduled status, as well as other campaign statuses if needed. Additionally, it includes the list name, the number of lists used, and the last sent date. The results are grouped by campaign month and list name, and ordered in descending order of the campaign month. |
| [`weld/core/monthly_flow_events.sql`](weld/core/monthly_flow_events.sql) · [dbt](dbt/models/core/core_klaviyo__monthly_flow_events.sql) | Monthly Flow Events | Generates a report of monthly flow events from the Klaviyo integration. It calculates the total number of events triggered and the number of distinct persons triggered for each flow in a given month. The result includes the month, flow ID, flow name, flow status, trigger type, total events triggered, and distinct persons triggered, ordered by month and flow name. |
| [`weld/core/monthly_user_engagement_per_campaign.sql`](weld/core/monthly_user_engagement_per_campaign.sql) · [dbt](dbt/models/core/core_klaviyo__monthly_user_engagement_per_campaign.sql) | Monthly User Engagement per Campaign | Calculates the monthly user engagement per campaign using data from Klaviyo integration. It extracts the year, month, campaign ID, event name, and counts the number of unique persons for specific events. It then aggregates the counts for each event type and campaign, grouping them by year, month, campaign ID, and campaign name. The final result is ordered by year, month, and campaign name. |

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

Corrected in review:

- `core/events_flow_campaign_report` reads from `{{staging.klaviyo.email_events}}`; the website version had a stray `select distinct event_name` in its FROM clause, a syntax error. The flow status column is aliased `flow_status`, which the final select reads.
- `staging/email_events` strips the `$` from Klaviyo's property keys before reading `flow` and `event_id`, as it already did for the other keys, so those two no longer come back NULL.

## Ported to the current schema

Every template now reads the tables and columns current Klaviyo connections sync.

- The event table holds `metric_id` and `profile_id` instead of `event_name` and `person_id`. The event name now comes from `klaviyo.metric`, joined on `metric_id`, and persons are counted by `profile_id`. `staging/email_events` reads `klaviyo.event` instead of `klaviyo_import.event` and still returns the profile id as `person_id`.
- The event's `campaign_id` and `flow_id` come from Klaviyo's attribution data for the event. Events with no attribution have them null and drop out of the per campaign and per flow reports.
- `staging/email_events` and `core/events_flow_campaign_report` no longer return `send_ts`. The attribution object in the event's Klaviyo properties holds the related ids only, so there is no send timestamp to read.
- `core/events_flow_campaign_report` returns `campaign_name` in place of `subject`, since the campaign table has no subject. `campaign_sent_at` now reads the campaign's `send_time`.
- `core/monthly_flow_events` no longer returns `trigger_filter` or `customer_filter`, which the flow table does not have.
- `core/monthly_campaign_status_breakdown_by_list` reads a campaign's lists from `campaign_audiences_included` instead of `campaign_list`. An audience can be a list or a segment, so `list_name` is the segment's name when the audience is a segment. The month comes from `created_at` and `last_sent_date` from `send_time`. The grouping by email template is gone: campaigns no longer carry a template id. Statuses are matched in lower case and each campaign is counted once per status.
- The website version's `l.list_name` read a column the list table does not have; it now reads `name`.

## Required tables

| Model | Raw tables |
|---|---|
| `staging/email_events` | `klaviyo.event`, `klaviyo.metric` |
| `core/events_flow_campaign_report` | `klaviyo.campaign`, `klaviyo.flow` · reads `staging.klaviyo.email_events` |
| `core/monthly_campaign_status_breakdown_by_list` | `klaviyo.campaign`, `klaviyo.campaign_audiences_included`, `klaviyo.list`, `klaviyo.segment` |
| `core/monthly_flow_events` | `klaviyo.event`, `klaviyo.flow` |
| `core/monthly_user_engagement_per_campaign` | `klaviyo.campaign`, `klaviyo.event`, `klaviyo.metric` |

## Models

### Email Events

`weld/staging/email_events.sql`

The SQL template named "email_events" is designed to work with the Klaviyo
integration. This SQL model retrieves various event-related information from the
Klaviyo platform. The selected fields include event ID, event timestamp, event name,
custom properties, Klaviyo properties, UUID, person ID, metric ID, campaign ID, flow
ID, flow, attributed event ID, message ID, send cohort, and order ID.

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
