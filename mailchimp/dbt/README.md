# Mailchimp dbt models

Drop-in model files. Not a runnable project: no `dbt_project.yml`, not run in CI.

```
models/staging/sources.yml                              one source, one Mailchimp account
models/staging/stg_mailchimp__*.sql                     9 thin wrappers over the raw tables
models/core/core_mailchimp__campaign_performance.sql    one row per sent campaign
models/core/core_mailchimp__audience_growth_daily.sql   subscribes, unsubscribes and sends per audience per day
models/core/core_mailchimp__audience_summary.sql        contact counts per audience, Mailchimp's and rebuilt
models/analytics/analytics__mailchimp_*.sql             thin BI-facing contracts
tests/assert_mailchimp__one_row_per_campaign_and_audience_day.sql  the stated grains hold
tests/assert_mailchimp__campaign_outcomes_within_recipients.sql    bounces, opens and clicks stay within recipients
```

Four layers, same as the Weld side: raw, staging, core, analytics. The analytics models
are `SELECT *` by design: dashboards bind to them so core stays free to change.

These are the same models as [`../weld/`](../weld/), differing only in ref syntax. They
are generated from the Weld versions, so the two dialects cannot disagree.

## You supply

**Your schema.** Change `schema:` in `sources.yml` to wherever your loader lands the
Mailchimp tables. Nothing else to configure.

## Notes

- **Plain SQL, no macros.** Every key already includes `list_id`, because Mailchimp's
  member id repeats across audiences.
- **Not run end to end.** Nothing here has been run against a warehouse. Reconcile a few
  campaigns against their Mailchimp reports before relying on the output.
