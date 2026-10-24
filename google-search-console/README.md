# Google Search Console templates

Rebuilds the Search Console Performance report in your warehouse: site totals,
queries, pages, and which pages compete for the same query. BigQuery.

Weld connector: **Google Search Console**
([docs](https://weld.app/docs/applications/google-search-console)).

| Model | Recreates | Grain |
|---|---|---|
| [`weld/core/site_performance_daily.sql`](weld/core/site_performance_daily.sql) · [dbt](dbt/models/core/core_google_search_console__site_performance_daily.sql) | Performance report totals, plus the anonymized-query gap | day × site |
| [`weld/core/query_performance_daily.sql`](weld/core/query_performance_daily.sql) · [dbt](dbt/models/core/core_google_search_console__query_performance_daily.sql) | Queries tab | day × site × query |
| [`weld/core/page_performance_daily.sql`](weld/core/page_performance_daily.sql) · [dbt](dbt/models/core/core_google_search_console__page_performance_daily.sql) | Pages tab | day × site × page |
| [`weld/core/query_page_monthly.sql`](weld/core/query_page_monthly.sql) · [dbt](dbt/models/core/core_google_search_console__query_page_monthly.sql) | Query × page split, for cannibalisation checks | month × site × query × page |

## Layers

```
raw.google_search_console.*   ELT output, untouched
  ↓
weld/staging/*.sql            4 thin wrappers: cast, rename
  ↓
weld/core/*.sql               the reports, all the business logic lives here
  ↓
weld/analytics/*.sql          BI-facing contracts, deliberately thin
```

Analytics models are `SELECT *` on purpose: dashboards bind to them, so core can be
changed without breaking anything downstream. `dbt/` holds the same models with dbt
refs, generated from the Weld versions; see [dbt/README.md](dbt/README.md).

Weld references map to folder paths, so `{{staging.google_search_console.site_analytics}}`
expects the model in a `staging > google_search_console` folder. Mirror that
structure or adjust the refs.

## Required tables

| Model | Raw tables |
|---|---|
| site performance daily | `site_analytics_web`, `keyword_site_analytics_web` |
| query performance daily | `keyword_site_analytics_web` |
| page performance daily | `page_analytics_web` |
| query page monthly | `keyword_page_analytics_web` |

The connector syncs each report once per search type (`_web`, `_image`, `_video`,
`_news`). The templates read web search, which is what the Performance report shows
by default. To include another type, `UNION ALL` its table in the staging model; the
`search_type` column keeps the rows apart.

## Three things that will bite you

**1. Average position must be weighted by impressions.** Search Console computes it
over impressions. Every model carries `weighted_position_sum` (position ×
impressions); to roll up to a week, month or folder, divide its sum by the sum of
impressions. Averaging `average_position` across rows gives a number that matches
nothing in the UI.

**2. Query tables do not add up to the site total.** Google withholds rare
("anonymized") queries from every table that has a `query` column, but keeps them in
the totals. On long-tail sites that can be a large share of impressions.
`site_performance_daily` reads totals from the property table and shows the gap as
`anonymized_clicks` and `anonymized_impressions`, so the difference is visible
instead of looking like missing data.

**3. Property totals and page totals count impressions differently.** The `site_`
and `keyword_site_` tables aggregate by property: one search showing two of your
pages is one impression. The `page_` and `keyword_page_` tables aggregate by page:
the same search is an impression for each page. Summing impressions over pages
therefore exceeds the site total. Clicks are not affected.

## Notes

- **Dates are Pacific Time,** as Search Console reports them, whatever your own
  timezone.
- **Recent days move.** Search Console finalises data after two to three days, and
  the connector re-reads the last three days on every sync, so the latest days will
  change after they first appear.
- **History is limited to 16 months** by Google. Your warehouse keeps whatever was
  synced before that.
- **Country codes are ISO 3166-1 alpha-3, lowercase** (`usa`, `dnk`); device is
  `desktop`, `mobile` or `tablet`.
- **Not run against a warehouse.** These models were checked for syntax and
  references only. Reconcile a month of clicks and impressions per site with the
  Performance report (web search, same date range) before relying on the output.

## Schema notes

The ERD matches the schema Weld syncs for every table used here. Weld
also syncs a legacy `analytics` stream (query × page, without
`search_type`) that is not in the ERD; it is superseded by
`keyword_page_analytics_web` and not used.

## Vendor docs

- [Search Analytics API: query](https://developers.google.com/webmaster-tools/v1/searchanalytics/query)
- [Performance report metrics and how they are calculated](https://support.google.com/webmasters/answer/7042828)
