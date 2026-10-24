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
| [`zoho-crm/`](zoho-crm/) | deal pipeline, deal flow by month, rep activity, account 360 |

### From the weld.app template library

Single-query reports, moved here from weld.app/templates. Each was reviewed and
corrected on the way in, but they are simpler than the model sets above and not
reconciled against the source systems. Each directory's README says where every
query sits, what was corrected, and any issues still open.

| | Models |
|---|---|
| [`hubspot/`](hubspot/) | new companies, contacts and deals by month, deals by stage, won/lost deals, activity by owner, contact-to-deal conversion |
| [`salesforce/`](salesforce/) | aggregated daily sales report |
| [`google-ads/`](google-ads/) | ad report, URL report, ad stats by country, cross-channel marketing report |
| [`facebook-ads/`](facebook-ads/) | ad report, conversion insights, cross-channel marketing report |
| [`linkedin-ads/`](linkedin-ads/) | creative report |
| [`tiktok-ads/`](tiktok-ads/) | ad report |
| [`snapchat-ads/`](snapchat-ads/) | ad report |
| [`pinterest-ads/`](pinterest-ads/) | ad report |
| [`microsoft-ads/`](microsoft-ads/) | account, campaign, ad group and ad reports |
| [`amazon-ads/`](amazon-ads/) | campaign, ad group, keyword and ad reports |
| [`google-analytics-4/`](google-analytics-4/) | account, campaign, channel, event, page path and user activity reports |
| [`instagram-business/`](instagram-business/) | profile overview, engagement, media performance, growth |
| [`klaviyo/`](klaviyo/) | email events, campaign engagement, campaign status by list, flow events |
| [`stripe/`](stripe/) | MRR chain: subscriptions to monthly normalised MRR to new/expansion/contraction/churn |
| [`economic/`](economic/) | invoice line items, order items |
| [`xero/`](xero/) | journal entries, invoice entries, monthly invoice summary, monthly sales, tracking details |
| [`intercom/`](intercom/) | monthly conversations, tickets, resolution time, tags, ratings, tickets by state |
| [`clickup/`](clickup/) | team overview, task dependencies, user activity, time tracking, checklist progress |
| [`amazon-mws/`](amazon-mws/) | monthly sales, inventory, financial, shipping, returns and order-update reports |

## Notes

- Written for BigQuery; adapt functions for other engines.
- Files are named for what they do. The model name inside keeps its source prefix
  (`shopify_sales_over_time`) so table names stay unambiguous in one schema.
- `dbt/` folders are model files, not runnable projects. Copy them into your own
  project and repoint the refs.
- **Treat every model as unverified until you have reconciled it against the source
  system.** Scope limits and validation status are in each file header.
