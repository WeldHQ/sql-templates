# TikTok Organic templates

Rebuilds TikTok Analytics for a business account in your warehouse: daily
followers, profile views and engagement, and a video list with lifetime views,
watch time and engagement rate. BigQuery.

Weld connector: **TikTok Organic**
([docs](https://weld.app/docs/applications/tiktok-organic)).

| Model | Recreates | Grain |
|---|---|---|
| [`weld/core/profile_performance_daily.sql`](weld/core/profile_performance_daily.sql) · [dbt](dbt/models/core/core_tiktok_organic__profile_performance_daily.sql) | Analytics Overview: followers, net new followers, profile views, video views, likes, comments, shares, engagement rate | day × account |
| [`weld/core/video_performance.sql`](weld/core/video_performance.sql) · [dbt](dbt/models/core/core_tiktok_organic__video_performance.sql) | Analytics Content: lifetime views, reach, engagement, watch time and completion per video | video (lifetime, as of last sync) |

## Layers

```
raw.tiktok_organic.*   ELT output, untouched
  ↓
weld/staging/*.sql     3 thin wrappers: cast, rename, dedupe, Unix time to timestamp
  ↓
weld/core/*.sql        the reports, all the business logic lives here
  ↓
weld/analytics/*.sql   BI-facing contracts, deliberately thin
```

Analytics models are `SELECT *` on purpose: dashboards bind to them, so core can be
changed without breaking anything downstream. `dbt/` holds the same models with dbt
refs, generated from the Weld versions; see [dbt/README.md](dbt/README.md).

Weld references map to folder paths, so `{{staging.tiktok_organic.video}}` expects
the model in a `staging > tiktok_organic` folder. Mirror that structure or adjust
the refs.

## Required tables

| Model | Raw tables |
|---|---|
| profile performance daily | `profile_metrics`, `profile` |
| video performance | `video`, `profile` |

## Three things that will bite you

**1. Followers is a running total, everything else is per day.** In
`profile_performance_daily`, `followers` is the account's follower count on the
day: use the last day of a period, never the sum. `follower_change` is net, so it
already subtracts unfollows. Views, likes, comments and shares count the day.

**2. Video metrics are lifetime snapshots.** TikTok gives no per-day numbers for a
video. `video_performance` holds each video's totals as of `metrics_as_of`, and
they keep growing while the video is watched. Compare videos of similar age, or
snapshot the model on a schedule if you need a video's curve over time.

**3. Engagement rate is a ratio.** Both models define it as likes, comments and
shares over video views. For a week, month or group of videos, divide summed
`engagements` by summed `video_views`. `reach` is unique viewers per video, so
it cannot be summed into an account reach.

## Notes

- **Recent days are incomplete.** TikTok processes a day 24 to 48 hours after it
  ends and reports 0 until then. The connector re-reads the last week once a
  day. A follower count of 0 is treated as not yet processed and left NULL;
  other metrics for the last two days may still read 0.
- **Days are UTC,** as TikTok's API reports them.
- **History starts at connection.** TikTok serves at most 60 days of daily
  account metrics, so the first sync goes back 60 days and the table grows from
  there. Videos are read from the sync start date in your Weld settings.
- **Analytics must be switched on** in the TikTok app, and audience breakdowns
  only exist for accounts with more than 100 followers.
- **`full_video_watched_rate`** is passed through as TikTok sends it. TikTok's
  documentation does not state whether it is a fraction or a percentage; check
  one video against the app before charting it. `average_share_watched` (average
  watch time over video length) is computed here as a cross-check.
- **Not run against a warehouse.** These models were checked for syntax and
  references only. Reconcile a week of followers and video views, and a few
  videos, with TikTok Analytics before relying on the output.

## Schema notes

The ERD matches the connector's definitions for every table used here. The
connector also syncs audience tables (`profile_audience_country`,
`profile_audience_gender`, `profile_audience_activity` by hour) and per-video
`video_impression_source` and `video_audience_country` shares; the templates do
not use them.

## Vendor docs

- [TikTok Accounts API: get account data](https://business-api.tiktok.com/portal/docs?id=1762228399168514)
- [TikTok Accounts API: get video data](https://business-api.tiktok.com/portal/docs?id=1762228421622786)
