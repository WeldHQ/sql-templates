# SendGrid dbt models

Drop-in model files. Not a runnable project: no `dbt_project.yml`, not run in CI.

```
models/staging/sources.yml                                one source, one SendGrid account
models/staging/stg_sendgrid__*.sql                        8 thin wrappers over the raw tables
models/core/core_sendgrid__email_stats_daily.sql          the account-wide delivery funnel per day
models/core/core_sendgrid__category_stats_daily.sql       the same, per category
models/core/core_sendgrid__mailbox_provider_stats_daily.sql  deliverability per receiving provider
models/core/core_sendgrid__suppressions_daily.sql         new bounces, blocks, spam reports, unsubscribes
models/analytics/analytics__sendgrid_*.sql                thin BI-facing contracts
tests/assert_sendgrid__one_row_per_day_and_category.sql             the de-duplication in staging holds
tests/assert_sendgrid__funnel_never_exceeds_requests.sql            delivered and processed stay within requests
```

Four layers, same as the Weld side: raw, staging, core, analytics. The analytics models
are `SELECT *` by design: dashboards bind to them so core stays free to change.

These are the same models as [`../weld/`](../weld/), differing only in ref syntax. They
are generated from the Weld versions, so the two dialects cannot disagree.

## You supply

**Your schema.** Change `schema:` in `sources.yml` to wherever your loader lands the
SendGrid tables. Nothing else to configure.

## Notes

- **Plain SQL, no macros.** To combine several SendGrid accounts, `UNION ALL` a block per
  account in each staging model with an account label, and add that label to the grain
  in core.
- **Not run end to end.** Nothing here has been run against a warehouse. Reconcile a
  month against SendGrid's Stats pages before relying on the output.
