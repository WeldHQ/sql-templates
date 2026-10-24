# Notion templates

Turns the rows of your Notion databases into something you can count: every
database row with its title and status, how fast each database grows, and how many
items sit in each status. BigQuery.

Weld connector: **Notion** ([docs](https://weld.app/docs/applications/notion)).

| Model | Answers | Grain |
|---|---|---|
| [`weld/core/database_pages.sql`](weld/core/database_pages.sql) · [dbt](dbt/models/core/core_notion__database_pages.sql) | Every database row with title, status, creator and staleness | page |
| [`weld/core/pages_created.sql`](weld/core/pages_created.sql) · [dbt](dbt/models/core/core_notion__pages_created.sql) | New rows per database per day | created date × data source × creator |
| [`weld/core/status_breakdown.sql`](weld/core/status_breakdown.sql) · [dbt](dbt/models/core/core_notion__status_breakdown.sql) | Items per status, and how long since they were touched (the board view as a table) | data source × status property × status |

Notion databases have no fixed schema: every workspace defines its own properties.
These models only rely on what every database has: a title, an optional status
property, and page metadata. Your own properties stay available in
`staging.notion.page_property`, one row per page × property, already typed.

## Layers

```
raw.notion.*           ELT output, untouched
  ↓
weld/staging/*.sql     4 thin wrappers: cast, rename, de-duplicate, flatten titles
  ↓
weld/core/*.sql        the reports, all business logic
  ↓
weld/analytics/*.sql   BI-facing contracts, deliberately thin
```

`dbt/` holds the same models with dbt refs, generated from the Weld versions; see
[dbt/README.md](dbt/README.md). With
[GitHub Sync](https://weld.app/docs/transformations/github-sync),
`{{staging.notion.page}}` expects the model in a `staging > notion` folder.

## Required tables

| Model | Raw tables |
|---|---|
| database pages | `page`, `page_property`, `data_source`, `user` |
| pages created | as above |
| status breakdown | as above |

## Building on it

To report on your own properties, pivot `staging.notion.page_property` for one data
source. For example, a "Priority" select and an "Estimate" number:

```sql
SELECT
    page_id,
    MAX(IF(property_name = 'Priority', string_value, NULL)) AS priority,
    MAX(IF(property_name = 'Estimate', number_value, NULL)) AS estimate
FROM {{staging.notion.page_property}}
GROUP BY page_id
```

Join the result to `core.notion.database_pages` on `page_id`.

## Schema notes

- **Only pages shared with the Weld integration are synced.** Notion's API returns
  what the integration has been given access to. A database missing here was not
  shared with it.
- **Property ids repeat across databases.** Every title property has the id
  `title`, so `page_property` is keyed on page and property id together.
- **Values are pre-typed.** `string_value` holds title, text,
  select, status, email, URL and unique id properties, `number_value`,
  `date_value` and `boolean_value` for their types and for formula results.
  Multi-select, people and relation values only exist as raw JSON in the `value`
  column of the raw table and are not parsed here.
- **People and relation values are capped at 25 entries per property** by Notion's
  API.
- **No status history.** Notion's API exposes a page's current values and its last
  edit time, not when a status was set, so there is no cycle time report.
  `days_since_last_edit` reflects any edit to the page.
- **Data sources.** Since Notion's 2025 API version a database can contain several
  data sources. Pages are matched on their parent data source; pages that only name
  a parent database are matched when that database has exactly one data source.

## Reconciling

Nothing here has been run against a live warehouse. Open a database in Notion,
group its board view by status, and compare the counts with `status_breakdown`
for that data source. Archived pages are excluded on both sides.

[Notion API: page properties](https://developers.notion.com/reference/page-property-values) ·
[data sources](https://developers.notion.com/reference/data-source)
