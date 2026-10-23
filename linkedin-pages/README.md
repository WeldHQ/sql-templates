# LinkedIn Pages templates

Rebuilds LinkedIn Page analytics in your warehouse: daily organic impressions and
engagement across a Page's posts, follower growth, and who the followers are.
BigQuery.

Weld connector: **LinkedIn Company Pages**
([docs](https://weld.app/docs/applications/linkedin-company-pages)).

| Model | Recreates | Grain |
|---|---|---|
| [`weld/core/page_performance_daily.sql`](weld/core/page_performance_daily.sql) · [dbt](dbt/models/core/core_linkedin_pages__page_performance_daily.sql) | Page analytics, Updates: impressions, unique impressions, clicks, reactions, comments, reposts, engagement rate | day × organization |
| [`weld/core/follower_growth_daily.sql`](weld/core/follower_growth_daily.sql) · [dbt](dbt/models/core/core_linkedin_pages__follower_growth_daily.sql) | Page analytics, Followers: new followers (organic and paid) and an estimated total per day | day × organization |
| [`weld/core/follower_demographics.sql`](weld/core/follower_demographics.sql) · [dbt](dbt/models/core/core_linkedin_pages__follower_demographics.sql) | Page analytics, Follower demographics: seniority, job function, industry, country, location, company size | organization × facet × segment (current snapshot) |

## Layers

```
raw.linkedin_pages.*   ELT output, untouched
  ↓
weld/staging/*.sql     10 thin wrappers: cast, rename, dedupe, epoch ms to date
  ↓
weld/core/*.sql        the reports, all the business logic lives here
  ↓
weld/analytics/*.sql   BI-facing contracts, deliberately thin
```

Analytics models are `SELECT *` on purpose: dashboards bind to them, so core can be
changed without breaking anything downstream. `dbt/` holds the same models with dbt
refs, generated from the Weld versions; see [dbt/README.md](dbt/README.md).

Weld references map to folder paths, so `{{staging.linkedin_pages.share_statistics_daily}}`
expects the model in a `staging > linkedin_pages` folder. Mirror that structure or
adjust the refs.

## Required tables

| Model | Raw tables |
|---|---|
| page performance daily | `share_statistics_time_bound` |
| follower growth daily | `follower_statistics_time_bound`, `total_follower_count` |
| follower demographics | `follower_statistics_by_seniority`, `_by_function`, `_by_industry`, `_by_geo_country`, `_by_geo`, `_by_staff_count_range`, `_by_association_type`, `total_follower_count` |

## Three things that will bite you

**1. Engagement rate is a ratio, so re-aggregate from counts.** LinkedIn's
`engagement` is clicks, reactions, comments and reposts over impressions for that
day. `page_performance_daily` keeps it as `engagement_rate` and also carries
`engagements`; for a week or month divide summed `engagements` by summed
`impressions`. Averaging the daily rate gives a number LinkedIn never shows.

**2. There is no daily follower total.** LinkedIn's API returns gains per day and
the follower count right now, nothing in between. `follower_growth_daily`
rebuilds `followers_estimated` backwards from today's count. Treat it as a curve,
not an audit figure: sum the gain columns to measure growth over a period, and
never sum `followers_estimated` or `current_follower_count` across days.

**3. Unique impressions and demographics do not add up.** `unique_impressions` is
unique members per day, so summing days overcounts. Demographic facets are capped
at the top 100 segments and skip members who left a field blank, so they sum to
less than the follower total; `share_of_followers` shows that gap.

## Notes

- **Organic only.** LinkedIn's Page statistics exclude sponsored activity. A
  member who likes a boosted post and later unlikes it can make `likes` negative
  for a day, as LinkedIn documents. Use the LinkedIn Ads templates for paid.
- **No per-post data.** The connector syncs Page level totals only, so post
  engagement rates cannot be built from it.
- **Days are UTC** and start at midnight UTC, which can shift a day against the
  Page analytics view in your browser's time zone.
- **History is 12 months.** LinkedIn only serves daily statistics for the last
  rolling 12 months; follower gains stop two days before today. The connector
  re-reads that window on every sync and keeps older days it synced before, but
  a full resync can only bring back 12 months.
- **Snapshots are replaced.** `total_follower_count` and the demographic tables
  are rewritten on every sync, so they describe the Page now. Schedule a
  snapshot of `follower_demographics` if you want to see it change.
- **Metric definitions were cross-checked** against Fivetran's open-source
  `dbt_linkedin_pages` package; the SQL here is written independently for
  Weld's schema.
- **Not run against a warehouse.** These models were checked for syntax and
  references only. Reconcile a month of impressions and new followers per Page
  with LinkedIn Page analytics before relying on the output.

## Schema notes

The ERD matches the schema Weld syncs for every table used here. The
connector also syncs `share_statistics` and `follower_statistics` (lifetime
totals without dates) and `organization_lookup` (Page profile details); the
templates do not need them.

What cannot be built: a post report (one row per post with its text, type,
publish date, lifecycle state, and impressions, clicks, reactions, comments and
reposts). That needs the Page's posts and per-post share statistics, and the
connector syncs neither; its share statistics are Page totals. Use the Page
level models here, or LinkedIn's post analytics export, for post questions.

## Vendor docs

- [Organization share statistics](https://learn.microsoft.com/en-us/linkedin/marketing/community-management/organizations/share-statistics)
- [Organization follower statistics](https://learn.microsoft.com/en-us/linkedin/marketing/community-management/organizations/follower-statistics)
- [Organization follower count (networkSizes)](https://learn.microsoft.com/en-us/linkedin/marketing/community-management/organizations/organization-lookup-api)
