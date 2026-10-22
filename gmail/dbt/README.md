# Gmail dbt models

Drop-in model files. Not a runnable project: no `dbt_project.yml`, not run in CI.

```
models/staging/sources.yml                           one source, one mailbox
models/staging/stg_gmail__*.sql                      4 thin wrappers over the raw tables
models/core/core_gmail__messages.sql                 one row per email: direction, addresses, subject
models/core/core_gmail__email_volume_daily.sql       sent and received per day
models/core/core_gmail__response_times.sql           how long received mail waits for a reply
models/core/core_gmail__correspondents_monthly.sql   who the mailbox talks to, per month
models/analytics/analytics__gmail_*.sql              thin BI-facing contracts
tests/assert_one_row_per_message.sql                 the label and header joins do not fan out
tests/assert_volume_reconciles_to_messages.sql       daily volume sums to the message list; no negative waits
```

Four layers, same as the Weld side: raw, staging, core, analytics. The analytics models
are `SELECT *` by design: dashboards bind to them so core stays free to change.

These are the same models as [`../weld/`](../weld/), differing only in ref syntax. They
are generated from the Weld versions, so the two dialects cannot disagree.

## You supply

**Your schema.** Change `schema:` in `sources.yml` to wherever your loader lands the Gmail
tables. Nothing else to configure.

## Notes

- **One mailbox per source.** To report on several mailboxes, `UNION ALL` a block per
  connection in each staging model, carry `mailbox_address` through, and add it to the
  window partitions in `core_gmail__messages` and `core_gmail__response_times`.
- **Timestamps are UTC.** Convert before taking `DATE()` if your day should follow your
  office.
- **Not run end to end.** Nothing here has been run against a warehouse. Spot-check a
  few threads against the Gmail web client before relying on the output.
