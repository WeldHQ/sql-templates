# YouTube Analytics templates

Rebuilds the core YouTube Studio analytics in your warehouse: channel totals,
per-video performance and traffic sources, from YouTube's bulk Reporting API.
BigQuery.

Weld connector: **YouTube Analytics**
([docs](https://weld.app/docs/applications/youtube-analytics)).

| Model | Recreates | Grain |
|---|---|---|
| [`weld/core/channel_performance_daily.sql`](weld/core/channel_performance_daily.sql) · [dbt](dbt/models/core/core_youtube_analytics__channel_performance_daily.sql) | Studio channel overview: views, watch time, subscribers | day × channel |
| [`weld/core/video_performance_daily.sql`](weld/core/video_performance_daily.sql) · [dbt](dbt/models/core/core_youtube_analytics__video_performance_daily.sql) | Studio Content tab: per-video views, retention, engagement, impressions and CTR | day × channel × video |
| [`weld/core/traffic_sources_daily.sql`](weld/core/traffic_sources_daily.sql) · [dbt](dbt/models/core/core_youtube_analytics__traffic_sources_daily.sql) | Studio "Traffic source types" | day × channel × traffic source type |
| [`weld/core/viewer_demographics_daily.sql`](weld/core/viewer_demographics_daily.sql) · [dbt](dbt/models/core/core_youtube_analytics__viewer_demographics_daily.sql) | Studio Audience tab, age and gender | day × channel × age group × gender |

## Layers

```
raw.youtube_analytics.*   ELT output, untouched
  ↓
weld/staging/*.sql        4 thin wrappers: cast, rename, label codes
  ↓
weld/core/*.sql           the reports, all the business logic lives here
  ↓
weld/analytics/*.sql      BI-facing contracts, deliberately thin
```

Analytics models are `SELECT *` on purpose: dashboards bind to them, so core can be
changed without breaking anything downstream. `dbt/` holds the same models with dbt
refs, generated from the Weld versions; see [dbt/README.md](dbt/README.md).

Weld references map to folder paths, so `{{staging.youtube_analytics.channel_basic}}`
expects the model in a `staging > youtube_analytics` folder. Mirror that structure
or adjust the refs.

## Required tables

| Model | Raw tables |
|---|---|
| channel performance daily | `channel_basic_a3`, `channel_reach_basic_a1` |
| video performance daily | `channel_basic_a3`, `channel_reach_basic_a1` |
| traffic sources daily | `channel_traffic_source_a3` |
| viewer demographics daily | `channel_demographics_a1`, `channel_basic_a3` |

These are channel reports. Content owner (CMS) accounts get the same reports under a
`content_owner_` prefix with `claimed_status` and `uploader_type` added; point the
staging models at those tables to use them.

## Notes

- **Averages are recomputed, never summed.** Average view duration is watch time
  over views; average percentage viewed and thumbnail CTR are weighted by views and
  impressions. Each model keeps the weighted sums (`view_percentage_weighted`,
  `thumbnail_ctr_weighted`) so a BI tool can roll up to a week or month correctly.
- **Subscribers come from channel-level rows too.** YouTube reports subscriptions
  made off a watch page (channel page, home feed) on rows with no video. Channel
  totals include them; video totals cannot. `subscribers_off_video` shows the
  difference.
- **Demographics are percentages, so they are weighted.** YouTube reports the age
  and gender split as a percentage of the views in each video, country and
  subscriber slice. `viewer_demographics_daily` multiplies each percentage by that
  slice's views to get `estimated_views`, then sums. Adding the raw percentages
  across videos or countries would weight a video with 3 views like one with
  30,000. The split covers signed-in viewers only, so compare shares with Studio,
  not totals.
- **Thumbnail CTR is kept in YouTube's unit.** The Reporting API describes it as a
  percentage without saying whether the file holds 0.05 or 5. Compare one video with
  Studio before formatting it.
- **No video titles.** The Reporting API returns IDs only. Join your own video list
  on `video_id` for names.
- **Data starts when the reporting job starts.** The connector creates a Reporting
  API job on first sync; YouTube generates daily reports from then on and backfills
  a limited window before it. Older history is not available from this API.
- **Reports can be regenerated.** YouTube re-issues a report when it corrects data.
  The connector upserts on every dimension, so a correction replaces the earlier rows.
- **Dates are Pacific Time,** as in YouTube Studio.
- **Numbers will not match Studio to the view.** Studio applies its own freshness
  and privacy thresholds, and the bulk reports are finalised later. Expect small
  differences on recent days.
- **Metric definitions were cross-checked** against Fivetran's open-source
  `dbt_youtube_analytics` package; the SQL here is written independently for
  Weld's schema.
- **Not run against a warehouse.** These models were checked for syntax and
  references only. Reconcile a closed month of views, watch time and subscribers per
  channel against YouTube Studio before relying on the output.

## Schema notes

The ERD matches the connector's definitions for every table used here.

## Vendor docs

- [YouTube Reporting API: channel reports](https://developers.google.com/youtube/reporting/v1/reports/channel_reports)
- [Dimensions, including traffic source codes](https://developers.google.com/youtube/reporting/v1/reports/dimensions)
- [Metrics](https://developers.google.com/youtube/reporting/v1/reports/metrics)
