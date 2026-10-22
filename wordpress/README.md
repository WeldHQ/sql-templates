# WordPress templates

A content audit and an editorial output report from your WordPress database: every
published post and page with its length, age and last edit, and what gets published
and edited each month. BigQuery.

Weld connector: **WordPress** ([docs](https://weld.app/docs/applications/wordpress)).
It replicates the site's MySQL database, so the raw tables are WordPress's own.

| Model | Recreates | Grain |
|---|---|---|
| [`weld/core/content_inventory.sql`](weld/core/content_inventory.sql) · [dbt](dbt/models/core/core_wordpress__content_inventory.sql) | The Posts and Pages lists, as a content audit: words, age, last edit, revisions, featured image | published post or page (current state) |
| [`weld/core/publishing_cadence.sql`](weld/core/publishing_cadence.sql) · [dbt](dbt/models/core/core_wordpress__publishing_cadence.sql) | Editorial output: posts and words published, edits made | month × post type × author |

## Layers

```
raw.wordpress.*         ELT output, untouched
  ↓
weld/staging/*.sql      2 thin wrappers: cast, rename, count words, de-duplicate
  ↓
weld/core/*.sql         the reports, all the business logic lives here
  ↓
weld/analytics/*.sql    BI-facing contracts, deliberately thin
```

Analytics models are `SELECT *` on purpose: dashboards bind to them, so core can be
changed without breaking anything downstream. `dbt/` holds the same models with dbt
refs, generated from the Weld versions; see [dbt/README.md](dbt/README.md).

Weld references map to folder paths, so `{{staging.wordpress.posts}}` expects the
model in a `staging > wordpress` folder. Mirror that structure or adjust the refs.

## Required tables

| Model | Raw tables |
|---|---|
| content inventory | `wp_posts`, `wp_postmeta` |
| publishing cadence | `wp_posts` |

`wp_` is WordPress's default table prefix. If your site uses another (common on
hosts that install WordPress for you), change the two raw refs in staging.

## Notes

- **Everything lives in `wp_posts`.** Posts, pages, revisions, attachments, menu
  items and auto-drafts are all rows in one table, told apart by `post_type`. The
  core models count `post` and `page` with status `publish`. Custom post types
  (products, events, case studies) have site-specific names: add yours to the `IN`
  lists in core.
- **Revisions are the edit history.** Each saved revision is a `wp_posts` row with
  `post_type = 'revision'` and the post as its parent. `edits` in
  `publishing_cadence` counts them, credited to whoever saved them. Autosaves are
  revisions too. Sites that limit or disable revisions (`WP_POST_REVISIONS`) will
  show fewer or none.
- **Dates are in the site's time zone,** from `post_date` and `post_modified`, so
  they match wp-admin. The UTC columns are kept in staging.
- **Word count is approximate.** HTML tags are stripped and words counted with a
  regular expression; shortcodes and text inside blocks that render something else
  are counted as written.
- **Published is the current state.** WordPress keeps no publish history, so a post
  unpublished today drops out of the month it was published in.
- **`is_stale` and `is_thin` are thresholds,** one year without an update and fewer
  than 300 words. Both are single constants in `content_inventory`; set them to your
  editorial policy.
- **Authors are IDs.** Names live in `wp_users`, which is not part of the published
  schema for this connector. If you sync it, join `author_id` to `wp_users.ID` for
  `display_name`. The same goes for categories and tags (`wp_terms`,
  `wp_term_taxonomy`, `wp_term_relationships`) and comments (`wp_comments`).
- **WooCommerce, Yoast SEO and MonsterInsights** have their own Weld connectors;
  these templates cover core WordPress content only.
- **Not run against a warehouse.** These models were checked for syntax and
  references only. Compare the count of published posts and pages with the numbers
  at the top of the Posts and Pages screens in wp-admin before relying on the output.

## Schema notes

The public ERD for this connector lists `wp_posts` and `wp_postmeta`, and the
models use only those. Because the connector replicates your own database, the other
standard WordPress tables are there if you choose to sync them.

## Vendor docs

- [WordPress database](https://developer.wordpress.org/advanced-administration/wordpress/database/)
- [Revisions](https://wordpress.org/documentation/article/revisions/)
