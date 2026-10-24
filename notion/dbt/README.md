# Notion dbt models

Drop-in model files. Not a runnable project: no `dbt_project.yml`, not run in CI.

```
models/staging/sources.yml                  one source
models/staging/stg_notion__*.sql            4 thin wrappers over the raw tables
models/core/core_notion__*.sql              the reports
models/analytics/analytics__notion_*.sql    thin BI-facing contracts
tests/assert_notion__one_row_per_page.sql           no fan-out in database_pages
tests/assert_notion__pages_created_reconciles.sql   daily counts sum to the page count
```

These are the same models as [`../weld/`](../weld/), differing only in ref syntax.
They are generated from the Weld versions, so the two cannot disagree.

## You supply

**Your schema.** Change `schema:` in `sources.yml` to wherever your loader lands the
Notion tables.

## Notes

- Plain SQL, no macros, no vars.
- Not run end to end. Compare one database's board view with `status_breakdown`
  before relying on the output.
