# Google Analytics 4 templates

SQL reports over Weld's Google Analytics 4 connector. BigQuery.

| Model | Report | What it returns |
|---|---|---|
| [`weld/core/account_report.sql`](weld/core/account_report.sql) · [dbt](dbt/models/core/core_google_analytics_4__account_report.sql) | Account Report | This SQL template generates a comprehensive account report by aggregating user statistics, campaign performance, and event data from Google Analytics. It combines these metrics to provide insights on total users, new users, sessions, user engagement, campaign details, and event revenue for each day. The results are ordered by date in descending order. |
| [`weld/core/campaign_report.sql`](weld/core/campaign_report.sql) · [dbt](dbt/models/core/core_google_analytics_4__campaign_report.sql) | Campaign Report | This SQL template generates a monthly summary report of campaign performance metrics from Google Analytics data. It aggregates data such as total users, sessions, engaged sessions, events per session, engagement rate, event count, conversions, total revenue, and user engagement duration. The results are ordered by period and total users in descending order. |
| [`weld/core/channel_traffic_overview.sql`](weld/core/channel_traffic_overview.sql) · [dbt](dbt/models/core/core_google_analytics_4__channel_traffic_overview.sql) | Channel Traffic Overview | This SQL template provides a monthly overview of channel traffic from Google Analytics, summarizing metrics such as total users, sessions, engaged sessions, events per session, engagement rate, event count, conversions, total revenue, and user engagement duration, grouped by channel. |
| [`weld/core/event_performance.sql`](weld/core/event_performance.sql) · [dbt](dbt/models/core/core_google_analytics_4__event_performance.sql) | Event Performance | This SQL template aggregates Google Analytics event data by month, summarizing event counts, user counts, average events per user, and total revenue for each event. It groups the data by period and event name, then orders the results by event count in descending order. |
| [`weld/core/page_path_analysis.sql`](weld/core/page_path_analysis.sql) · [dbt](dbt/models/core/core_google_analytics_4__page_path_analysis.sql) | Page Path Analysis | Monthly page path metrics per property: screen page views, users, new users, events, conversions, revenue and engagement time. |
| [`weld/core/user_activity_overview.sql`](weld/core/user_activity_overview.sql) · [dbt](dbt/models/core/core_google_analytics_4__user_activity_overview.sql) | User Activity Overview | This SQL template aggregates monthly user activity data from Google Analytics, including total users, new users, sessions, average sessions per user, screen page views, and user engagement duration. |

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

- `core/user_activity_overview` groups by calendar month (`DATE_TRUNC`) and property; the website version's `EXTRACT(MONTH ...)` merged the same month across years. `sessions_per_user` divides the month's totals instead of averaging daily ratios.
- `core/page_path_analysis` no longer joins the channel report, which repeated every page once per channel and multiplied every sum. The page path report has no channel dimension, so `traffic_source` is gone and `property_id` is added.
- `core/account_report` joins event stats on property as well as date.

## Required tables

| Model | Raw tables |
|---|---|
| `core/account_report` | `google_analytics_4.audience_overview`, `google_analytics_4.campaign_performance`, `google_analytics_4.events_overview` |
| `core/campaign_report` | `google_analytics_4.campaign_performance` |
| `core/channel_traffic_overview` | `google_analytics_4.channel_traffic` |
| `core/event_performance` | `google_analytics_4.events_overview` |
| `core/page_path_analysis` | `google_analytics_4.channel_traffic`, `google_analytics_4.page_path` |
| `core/user_activity_overview` | `google_analytics_4.audience_overview` |

## Models

### Account Report

`weld/core/account_report.sql`

The Account Report SQL model aggregates and combines data from Google Analytics to
provide a comprehensive overview of user activity, campaign performance, and event
metrics for different properties. By extracting daily statistics, it offers insights
into total and new users, session counts, user engagement duration, campaign-
specific user and session data, engagement rates, event counts, and revenue. This
model is useful for understanding user behavior trends, evaluating the effectiveness
of marketing campaigns, and analyzing event-driven revenue, helping businesses make
data-driven decisions to optimize their online presence and marketing strategies.

### Campaign Report

`weld/core/campaign_report.sql`

The Campaign Report SQL model is designed to aggregate and analyze campaign
performance data from Google Analytics. By summarizing key metrics such as total
users, sessions, engaged sessions, events per session, engagement rate, event count,
conversions, total revenue, and user engagement duration, this model provides a
comprehensive overview of campaign effectiveness over specified periods. This SQL
template is particularly useful for marketers and analysts looking to track the
performance of different campaigns, identify trends, and make data-driven decisions
to optimize marketing strategies. The output allows users to compare campaigns based
on user engagement and revenue generation, helping to pinpoint which campaigns are
most successful and where improvements can be made.

### Channel Traffic Overview

`weld/core/channel_traffic_overview.sql`

The "Channel Traffic Overview" SQL model provides a comprehensive summary of traffic
data from Google Analytics. By aggregating data on a monthly basis (modifiable to
daily), it offers insights into various metrics segmented by traffic channels. This
model is useful for understanding user behavior and engagement across different
channels, tracking the performance of marketing campaigns, and identifying the most
effective channels in driving traffic and revenue. Key metrics include total users,
sessions, engaged sessions, events per session, engagement rate, event count,
conversions, total revenue, and user engagement duration. This information can help
businesses optimize their marketing strategies and improve user engagement.

### Event Performance

`weld/core/event_performance.sql`

The "Event Performance" SQL model for Google Analytics integration provides a
comprehensive overview of event metrics over specified periods, such as months or
days. By aggregating data from the Google Analytics 4 events overview, this model
calculates total event counts, user counts, average events per user, and total
revenue generated by events. This SQL model is particularly useful for understanding
user engagement and behavior, identifying high-performing events, and assessing the
revenue impact of different events. It enables businesses to make data-driven
decisions to optimize their event strategies and improve overall performance.

### Page Path Analysis

`weld/core/page_path_analysis.sql`

A monthly view of page paths per GA4 property: screen page views, total users,
new users, event count, conversions, total revenue and user engagement duration.
Switch the truncation to DAY for a daily view. GA4's page path report has no
traffic source dimension, so this model does not split pages by channel.

### User Activity Overview

`weld/core/user_activity_overview.sql`

The "User Activity Overview" SQL model leverages Google Analytics data to provide a
comprehensive monthly summary of user engagement metrics. This SQL query extracts
and aggregates data from the Google Analytics 4 audience overview, grouping the
results by month. Key metrics include the total number of users, new users,
sessions, average sessions per user, screen page views, and user engagement
duration. This model is useful for identifying trends in user activity over time,
understanding user engagement patterns, and making data-driven decisions to enhance
user experience and optimize marketing strategies.
