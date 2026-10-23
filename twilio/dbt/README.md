# Twilio dbt models

Drop-in model files. Not a runnable project: no `dbt_project.yml`, not run in CI.

```
models/staging/sources.yml                        one source, one Twilio account
models/staging/stg_twilio__message.sql            one row per message, price as positive cost
models/staging/stg_twilio__call.sql               one row per call leg, price as positive cost
models/staging/stg_twilio__messaging_service.sql  one row per Messaging Service, for its name
models/core/core_twilio__messaging_daily.sql      volume, delivery and spend per day
models/core/core_twilio__message_errors_daily.sql failed and undelivered messages by error code
models/core/core_twilio__calls_daily.sql          call outcomes, minutes and spend per day
models/analytics/analytics__twilio_*.sql          thin BI-facing contracts
tests/assert_one_row_per_message_and_call.sql     the de-duplication in staging holds
tests/assert_costs_are_not_negative.sql           the price sign flip holds
```

Four layers, same as the Weld side: raw, staging, core, analytics. The analytics models
are `SELECT *` by design: dashboards bind to them so core stays free to change.

These are the same models as [`../weld/`](../weld/), differing only in ref syntax. They
are generated from the Weld versions, so the two dialects cannot disagree.

## You supply

**Your schema.** Change `schema:` in `sources.yml` to wherever your loader lands the
Twilio tables. Nothing else to configure.

## Notes

- **Plain SQL, no macros.** Subaccounts already carry their own `account_sid`, which is
  part of every grain.
- **Not run end to end.** Nothing here has been run against a warehouse. Reconcile a
  closed month against Twilio's Messaging Insights and your usage invoice before relying
  on the output.
