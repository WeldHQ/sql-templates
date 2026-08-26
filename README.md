# SQL templates

SQL models that rebuild source-system reports in your own warehouse.

Each integration ships both dialects:

- `weld/` — Weld transforms, `{{raw.source.table}}` refs
- `dbt/` — drop-in model files, `{{ source() }}` / `{{ ref() }}` refs

## Integrations

| | Models |
|---|---|
| [`shopify/`](shopify/) | sales over time, product sales over time, SKU cost per day, sales by product |
| [`amazon-seller-central/`](amazon-seller-central/) | sales over time, product sales over time, settlement ledger, ASIN profitability, traffic and conversion, inventory health |
| [`amazon-vendor-central/`](amazon-vendor-central/) | sales over time, sales by ASIN, inventory health, forecast vs actuals |

The rest of the library is at [weld.app/templates](https://weld.app/templates).

## Notes

- Written for BigQuery; adapt functions for other engines.
- Files are named for what they do. The model name inside keeps its source prefix
  (`shopify_sales_over_time`) so table names stay unambiguous in one schema.
- `dbt/` folders are model files, not runnable projects. Copy them into your own
  project and repoint the refs.
- **Treat every model as unverified until you have reconciled it against the source
  system.** Scope limits and validation status are in each file header.
