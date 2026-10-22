# Google Business Profile templates

Rebuilds the Business Profile Performance view per location: how often each
profile was shown, what people did with it, which searches found it, and how
reviews and replies are trending. BigQuery.

Weld connector: **Google My Business Profile**
([docs](https://weld.app/docs/applications/google-my-business-profile)).

| Model | Recreates | Grain |
|---|---|---|
| [`weld/core/location_performance_daily.sql`](weld/core/location_performance_daily.sql) · [dbt](dbt/models/core/core_google_my_business_profile__location_performance_daily.sql) | Performance: views by surface, calls, directions, website clicks, messages, bookings | day × location |
| [`weld/core/search_keywords_monthly.sql`](weld/core/search_keywords_monthly.sql) · [dbt](dbt/models/core/core_google_my_business_profile__search_keywords_monthly.sql) | Performance: searches that showed the profile | month × location × keyword |
| [`weld/core/reviews_monthly.sql`](weld/core/reviews_monthly.sql) · [dbt](dbt/models/core/core_google_my_business_profile__reviews_monthly.sql) | Reviews: new reviews, rating, reply rate, running average | month × location |

## Layers

```
raw.google_my_business_profile.*   ELT output, untouched
  ↓
weld/staging/*.sql                 4 thin wrappers: cast, rename, map enums
  ↓
weld/core/*.sql                    the reports, all the business logic lives here
  ↓
weld/analytics/*.sql               BI-facing contracts, deliberately thin
```

Analytics models are `SELECT *` on purpose: dashboards bind to them, so core can be
changed without breaking anything downstream. `dbt/` holds the same models with dbt
refs, generated from the Weld versions; see [dbt/README.md](dbt/README.md).

Weld references map to folder paths, so `{{staging.google_my_business_profile.review}}`
expects the model in a `staging > google_my_business_profile` folder. Mirror that
structure or adjust the refs.

## Required tables

| Model | Raw tables |
|---|---|
| location performance daily | `location_performance_daily`, `account_location` |
| search keywords monthly | `location_search_keywords_impressions_monthly`, `account_location` |
| reviews monthly | `review`, `account_location` |

## Notes

- **The daily table is long, core makes it wide.** The connector stores one row per
  location, day and metric. Core pivots the eleven metrics Google publishes into
  columns. A metric Google adds later is ignored until you add a column for it.
- **Impressions are unique users per day per surface.** Google counts a person who
  sees the profile several times in a day once, separately on desktop and mobile
  Maps and Search. Summing days gives "daily views", not unique viewers.
- **Interactions** add up calls, messages, bookings, directions, website clicks,
  food orders and menu clicks, the actions Google counts as profile interactions.
- **Keyword counts have a floor.** Below a threshold Google returns only the
  threshold, not the count. `search_keywords_monthly` keeps those rows with
  `is_below_threshold` and an upper bound, so totals are a range.
- **Ratings are rebuilt from the reviews still on the profile.** Deleted or removed
  reviews drop out of the API, so the running average can differ slightly from the
  rating Google shows on Maps, which it computes and rounds itself.
- **Reply time is approximate.** The API gives the reply's last update time, not
  when it was first posted, so an edited reply looks slow.
- **History:** the connector reads 18 months of daily metrics on the first sync,
  re-reads the last three days afterwards, and Google publishes a day's metrics with
  a delay of a few days. Keyword data arrives a month in arrears.
- **Not run against a warehouse.** These models were checked for syntax and
  references only. Reconcile one month for one location against the Performance
  view in Business Profile Manager before relying on the output.

## Schema notes

The ERD matches the connector's definitions for every table used here. In the
ERD, `review.review_id` is drawn as a foreign key to `review` itself; it is the
review's own id.

## Vendor docs

- [Business Profile Performance API: DailyMetric](https://developers.google.com/my-business/reference/performance/rest/v1/DailyMetric)
- [Search keywords impressions](https://developers.google.com/my-business/reference/performance/rest/v1/locations.searchkeywords.impressions.monthly/list)
- [Reviews (v4)](https://developers.google.com/my-business/reference/rest/v4/accounts.locations.reviews)
