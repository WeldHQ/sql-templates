# Instagram Business templates

SQL reports over Weld's Instagram Business connector. BigQuery.

| Model | Report | What it returns |
|---|---|---|
| [`weld/core/engagement_metric_analysis.sql`](weld/core/engagement_metric_analysis.sql) · [dbt](dbt/models/core/core_instagram_business__engagement_metric_analysis.sql) | Engagment Metric Analysis | Calculates various engagement metrics for Instagram Business accounts on a monthly basis. It retrieves data such as the total number of media posts, likes, comments, feed engagement, carousel engagement, reel likes, reel comments, story replies, and story exits. Additionally, it calculates average engagement per post metrics, including average likes, comments, feed engagement, carousel engagement, reel likes, and reel comments per post. The results are ordered by month in descending order. |
| [`weld/core/growth_analysis.sql`](weld/core/growth_analysis.sql) · [dbt](dbt/models/core/core_instagram_business__growth_analysis.sql) | Growth Analysis | Calculates the growth rates of various metrics for an Instagram Business account. It retrieves monthly data on average followers, average follows, total feed engagement, total carousel engagement, and total reel likes. It then calculates the growth rate percentages for each metric compared to the previous month. The results are sorted by month in descending order. |
| [`weld/core/media_insights_deep_dive.sql`](weld/core/media_insights_deep_dive.sql) · [dbt](dbt/models/core/core_instagram_business__media_insights_deep_dive.sql) | Media Insights Deep Dive | Retrieves various metrics for different types of media posts (carousel, reel, story, feed). It also calculates engagement rates for each type of media. The template joins the media data with the media history table to include additional information such as caption, timestamp, media type, likes count, and comments count. The final result is sorted by month and media posted date in descending order. |
| [`weld/core/media_performance_report.sql`](weld/core/media_performance_report.sql) · [dbt](dbt/models/core/core_instagram_business__media_performance_report.sql) | Media Performance Report | Generates a media performance report for Instagram Business integration. It combines metrics from the media_history and media_insights tables to provide a comprehensive view of monthly media performance. The report includes metrics such as total media posts, likes, comments, carousel engagement, impressions, reach, reel likes, plays, feed engagement, impressions, and reach. |
| [`weld/core/profile_overview_report.sql`](weld/core/profile_overview_report.sql) · [dbt](dbt/models/core/core_instagram_business__profile_overview_report.sql) | Profile Overview Report | Profile overview report for Instagram Business integration. It combines data from different tables to calculate average follows count, average followers count, average profile views, and average website clicks for each user on a monthly basis. The results are then ordered by month. |
| [`weld/core/user_engagement_and_outreach_report.sql`](weld/core/user_engagement_and_outreach_report.sql) · [dbt](dbt/models/core/core_instagram_business__user_engagement_and_outreach_report.sql) | User Engagement and Outreach Report | Generates a report on user engagement and outreach for an Instagram Business integration. It combines data from various tables to calculate average follower count, profile views, website clicks, like count, comments count, feed impressions, and feed reach on a monthly basis. The result is sorted by month and user ID. |

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

- `core/engagement_metric_analysis`, `core/growth_analysis`, `core/media_performance_report` and `core/media_insights_deep_dive` count each post once, from its latest `media_history` snapshot, and date it by the month it was posted rather than when Weld synced it. The website versions summed every snapshot of a post.
- `core/growth_analysis` works out followers per account by snapshot month and engagement per account by post month, then compares each account's months. The website version joined every account snapshot to every post. Follower counts stay dated by `_weld_synced_at` on purpose: Instagram only returns the current count, so the snapshot time is when it was measured.
- Instagram has renamed some media metrics. The queries now read `story_tap_exit`, `story_tap_back`, `story_tap_forward` and `reel_views`; `media_performance_report` outputs `total_reel_views` in place of `total_reel_plays`.

## Required tables

| Model | Raw tables |
|---|---|
| `core/engagement_metric_analysis` | `instagram.media_history`, `instagram.media_insights` |
| `core/growth_analysis` | `instagram.media_history`, `instagram.media_insights`, `instagram.user_history` |
| `core/media_insights_deep_dive` | `instagram.media_history`, `instagram.media_insights` |
| `core/media_performance_report` | `instagram.media_history`, `instagram.media_insights` |
| `core/profile_overview_report` | `instagram.user_history`, `instagram.user_insights` |
| `core/user_engagement_and_outreach_report` | `instagram.media_history`, `instagram.media_insights`, `instagram.user_history`, `instagram.user_insights` |

## Models

### Engagment Metric Analysis

`weld/core/engagement_metric_analysis.sql`

The SQL template "Engagement Metric Analysis" is designed for analyzing engagement
metrics from Instagram Business integration. It retrieves data from the tables
"media_history" and "media_insights" in the Instagram database.

### Growth Analysis

`weld/core/growth_analysis.sql`

The Growth Analysis SQL template is designed to analyze the growth rates of various
metrics for an Instagram Business account. By integrating with Instagram Business
data, this SQL template calculates the percentage growth rates for average
followers, average follows, total feed engagement, total carousel engagement, and
total reel likes on a monthly basis.

### Media Insights Deep Dive

`weld/core/media_insights_deep_dive.sql`

The SQL template "Media Insights Deep Dive" is designed to provide a comprehensive
analysis of media performance on Instagram Business. It integrates with the
Instagram Business API to retrieve data and generate insights.

### Media Performance Report

`weld/core/media_performance_report.sql`

The SQL template "Media Performance Report" is designed to analyze the performance
of Instagram Business accounts. It combines data from two tables, "media_history"
and "media_insights", to provide a comprehensive view of media metrics.

### Profile Overview Report

`weld/core/profile_overview_report.sql`

The Profile Overview Report SQL template is designed to provide an overview of key
metrics for Instagram Business profiles. By integrating with Instagram's user
history and user insights data, this SQL model calculates average values for metrics
such as follows count, followers count, profile views, and website clicks on a
monthly basis.

### User Engagement and Outreach Report

`weld/core/user_engagement_and_outreach_report.sql`

The SQL template "User Engagement and Outreach Report" is designed to analyze user
engagement and outreach data from Instagram Business. It consists of three main
subqueries: MonthlyFollowers, MonthlyProfileEngagement, and MonthlyMediaEngagement.

## Known issues

Still open after the review, with the reason each is left as it is.

- `core/profile_overview_report` and `core/user_engagement_and_outreach_report` read `profile_views` and `website_clicks` from `user_insights`, which the connector does not sync (it holds follower count and reach by date). They fail as published, and there is no source in the connector for those two metrics, so they are left as they are. They also still bucket by `_weld_synced_at`.
