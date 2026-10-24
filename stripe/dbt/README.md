# Stripe dbt models

Drop-in model files. Not a runnable project: no `dbt_project.yml`, not run in CI.

These are the same queries as [`../weld/`](../weld/), differing only in ref syntax:
`{{raw.x.y}}` becomes `{{ source('x', 'y') }}` and model refs become `{{ ref() }}`.

## You supply

**Your schema.** Change `schema:` in `models/staging/sources.yml` to wherever your
loader lands the tables.

## Notes

- No tests ship with these models.
- Not run end to end. Reconcile against the source system before relying on the output.
- See [`../README.md`](../README.md) for what each model returns and any known issues.
