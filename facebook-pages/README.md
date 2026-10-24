# Facebook Pages templates

Rebuilds Facebook Page Insights in your warehouse: daily followers, views,
engagement and Page visits, and a post list with lifetime engagement rates.
BigQuery.

Weld connector: **Facebook Pages**
([docs](https://weld.app/docs/applications/facebook-pages)).

| Model | Recreates | Grain |
|---|---|---|
| [`weld/core/page_performance_daily.sql`](weld/core/page_performance_daily.sql) · [dbt](dbt/models/core/core_facebook_pages__page_performance_daily.sql) | Page Insights overview: followers, new likes, views, viewers, engagement, Page visits, video views | day × Page |
| [`weld/core/post_performance.sql`](weld/core/post_performance.sql) · [dbt](dbt/models/core/core_facebook_pages__post_performance.sql) | Post list: lifetime views, viewers, reactions, comments, shares, clicks, engagement rate | post (lifetime, as of last sync) |

## Layers

```
raw.facebook_pages.*   ELT output, untouched
  ↓
weld/staging/*.sql     4 thin wrappers: cast, rename, dedupe, insight end_time to day
  ↓
weld/core/*.sql        the reports, all the business logic lives here
  ↓
weld/analytics/*.sql   BI-facing contracts, deliberately thin
```

Analytics models are `SELECT *` on purpose: dashboards bind to them, so core can be
changed without breaking anything downstream. `dbt/` holds the same models with dbt
refs, generated from the Weld versions; see [dbt/README.md](dbt/README.md).

Weld references map to folder paths, so `{{staging.facebook_pages.post}}` expects
the model in a `staging > facebook_pages` folder. Mirror that structure or adjust
the refs.

## Required tables

| Model | Raw tables |
|---|---|
| page performance daily | `page_daily_insights`, `page` |
| post performance | `post`, `post_lifetime_insights`, `page` |

**More than one Page.** With a single Page the post tables are called `post` and
`post_lifetime_insights`. When the connection covers several Pages, there is one
set per Page, named `<page_name>__<page_id>__post` and
`<page_name>__<page_id>__post_lifetime_insights`. `UNION ALL` them in the two
staging models; `page_id` and `post_id` keep the rows apart. The Page level
tables always hold every Page.

## Three things that will bite you

**1. Some metrics are running totals.** `followers` (Facebook's `page_follows`)
is the follower count at the end of each day: take the last day of a period,
never the sum. Post metrics are lifetime totals that keep growing while a post
is live, so `post_performance` is a snapshot as of `metrics_as_of`. Everything
else in `page_performance_daily` counts the day itself and can be summed, except
`viewers`, which is unique people per day.

**2. Impressions and reach are gone.** Meta removed Page and post impressions and
reach from the API on 15 June 2026 and replaced them with views and viewers. The
`_legacy` columns hold the old metrics for days and posts synced before then and
are empty afterwards. Views count every time content is shown or played, so they
are not a continuation of impressions; chart them as separate series.

**3. Engagement rate is a ratio.** `post_performance.engagement_rate` is
reactions, comments, shares and clicks over viewers. For a group of posts divide
summed `engagements` by summed `viewers`; averaging the rate over posts weights a
post seen by 50 people like one seen by 50,000.

## Notes

- **Days are Pacific Time.** Facebook stamps a daily value with midnight Pacific
  of the next day; staging turns that into the day the value belongs to, which
  is how Page Insights shows it.
- **Reactions, comments and shares** on posts come from Meta's activity by action
  type metric, which Meta counts as stories about the post. They can differ a
  little from the counters shown on the post itself.
- **Unique counts are estimates.** Meta marks viewers and new likes as estimated;
  small differences against Page Insights are expected.
- **Video view time** arrives in milliseconds and is converted to seconds.
- **History:** the first sync covers up to 36 months of daily Page insights and
  continues incrementally. Post insights are re-read for every post on every sync.
- **Follower change needs consecutive days.** `follower_change` compares with the
  previous calendar day and is NULL when that day has no row, so a gap in the
  sync never shows up as a one-day jump.
- **Not run against a warehouse.** These models were checked for syntax and
  references only. Reconcile a month of followers and views per Page, and a few
  posts, with Page Insights or Meta Business Suite before relying on the output.

## Schema notes

The ERD matches the schema Weld syncs for every table used here. The
connector also syncs `page_lifetime_insights`, `post_daily_insights` (video
metrics per day), `post_comment`, `post_reaction`, `video` and
`video_lifetime_insights`; the templates do not need them. The ERD draws only
the single-Page table names; the per-Page names above are how they appear in the warehouse.

## Vendor docs

- [Page Insights metrics](https://developers.facebook.com/docs/graph-api/reference/insights)
- [Deprecated Page Insights metrics (June 2026)](https://developers.facebook.com/docs/platforminsights/page/deprecated-metrics)
- [Page posts](https://developers.facebook.com/docs/graph-api/reference/page/feed)
