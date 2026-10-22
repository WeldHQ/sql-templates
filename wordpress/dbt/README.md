# WordPress dbt models

Drop-in model files. Not a runnable project: no `dbt_project.yml`, not run in CI.

```
models/staging/sources.yml                             one source, one site database
models/staging/stg_wordpress__posts.sql                every wp_posts row, with word count
models/staging/stg_wordpress__postmeta.sql             wp_postmeta key-value pairs
models/core/core_wordpress__content_inventory.sql      published posts and pages, as a content audit
models/core/core_wordpress__publishing_cadence.sql     published and edited per month and author
models/analytics/analytics__wordpress_*.sql            thin BI-facing contracts
tests/assert_inventory_is_unique.sql                   one row per post
tests/assert_cadence_reconciles_to_inventory.sql       monthly counts add up to the inventory
```

These are the same models as [`../weld/`](../weld/), differing only in ref syntax.

## You supply

- **Your schema and table prefix.** Change `schema:` in `sources.yml`, and the table
  names if your site does not use the `wp_` prefix.

## Notes

- Plain SQL, no macros, no vars.
- Not run end to end. Compare published counts with wp-admin before relying on the
  output.
