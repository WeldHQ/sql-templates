# LinkedIn Ads templates

Daily ad, campaign and campaign group performance from LinkedIn Ads, in the same
shape as the other paid ads templates in this repo. BigQuery.

Weld connector: **LinkedIn Ads** ([docs](https://weld.app/docs/applications/linkedin-ads)).

| Model | Recreates | Grain |
|---|---|---|
| [`weld/core/ad_performance_daily.sql`](weld/core/ad_performance_daily.sql) · [dbt](dbt/models/core/core_linkedin_ads__ad_performance_daily.sql) | Campaign Manager, Ads view, by day | day × ad account × creative |
| [`weld/core/campaign_performance_daily.sql`](weld/core/campaign_performance_daily.sql) · [dbt](dbt/models/core/core_linkedin_ads__campaign_performance_daily.sql) | Campaign Manager, Campaigns view, by day, with CTR, CPC, CPM, cost per conversion, ROAS and cost per lead | day × ad account × campaign |
| [`weld/core/campaign_group_performance_daily.sql`](weld/core/campaign_group_performance_daily.sql) · [dbt](dbt/models/core/core_linkedin_ads__campaign_group_performance_daily.sql) | Campaign Manager, Campaign groups view, by day | day × ad account × campaign group |

LinkedIn's hierarchy is ad account > campaign group > campaign > creative. A
creative is LinkedIn's ad, so `ad_id` and `ad_name` are the creative's id and title.

## Cross-channel contract

`ad_performance_daily` and `campaign_performance_daily` both carry `date_day,
account_id, account_name, currency, campaign_id, campaign_name, spend, impressions,
clicks, conversions, conversion_value, ctr, cpc, cpm, cost_per_conversion, roas`
with the same names and meanings as the other paid ads templates here, so they can
be stacked with `UNION ALL`. The ad model adds `ad_id`, `ad_name` and the campaign
group as its grouping level. `source` tells the rows apart. Spend is in each ad
account's own currency; `spend_usd` is LinkedIn's own USD conversion, handy when
accounts bill in different currencies.

### What counts as a conversion

- `conversions` = external website conversions, post-click plus post-view, under
  the attribution windows set on each conversion rule in Campaign Manager
  (LinkedIn's defaults are 30 days after a click and 7 days after a view). This
  is the "Conversions" column in Campaign Manager.
- Lead Gen Form submissions are **not** in `conversions`. They are in `leads`
  (LinkedIn's one-click leads), with `cost_per_lead` beside them.
- `conversion_value` is the value attributed to website conversions; NULL when no
  conversion rule carries a value, which makes `roas` NULL too.

For a lead generation account, report `leads` and `cost_per_lead`, or add `leads`
to `conversions` in `weld/core/ad_performance_daily.sql` if your cross-channel
report should count form fills as conversions. Post-click and post-view
conversions are kept as separate columns so a click-only figure can be rebuilt.

## Layers

```
raw.linkedin_ads.*        ELT output, untouched
  ↓
weld/staging/*.sql        5 thin wrappers: cast, rename, de-duplicate
  ↓
weld/core/*.sql           the reports, all the business logic lives here
  ↓
weld/analytics/*.sql      BI-facing contracts, deliberately thin
```

Analytics models are `SELECT *` on purpose: dashboards bind to them, so core can be
changed without breaking anything downstream. `dbt/` holds the same models with dbt
refs, generated from the Weld versions; see [dbt/README.md](dbt/README.md).

Weld references map to folder paths, so `{{staging.linkedin_ads.creative}}` expects
the model in a `staging > linkedin_ads` folder. Mirror that structure or adjust the
refs.

## Required tables

| Model | Raw tables |
|---|---|
| ad performance daily | `ad_analytics_by_creative`, `creative`, `campaign`, `campaign_group`, `account` |
| campaign performance daily | the same, through `ad_performance_daily` |
| campaign group performance daily | the same, through `campaign_performance_daily` |

## Notes

- **Money is in account currency, not micros.** Spend is
  `cost_in_local_currency`, the ad account's billing currency, which is what
  Campaign Manager shows. The connector also syncs `cost_in_usd`; it is kept as
  `spend_usd` and is not used for the contract columns.
- **Clicks are chargeable clicks,** LinkedIn's `clicks` metric: clicks to the
  landing page, company page and similar, not every social action. Clicks to the
  landing page alone are in `landing_page_clicks`.
- **Days are UTC.** LinkedIn's analytics API buckets daily data in UTC. If Campaign
  Manager shows a different time zone for your account, single days will not
  match exactly; weeks and months will be close.
- **Late conversions.** LinkedIn keeps adding conversions to past days for as long
  as the attribution window runs. The connector's incremental runs re-read from
  the day of the previous run onwards, so conversions that arrive later for older
  days are only picked up by a full refresh of the analytics stream. Spend,
  impressions and clicks settle within a day or two.
- **Account comes from the creative.** The creative analytics table has no account
  column, so the account, campaign and campaign group are looked up through the
  creative. Creatives missing from the `creative` table (and creatives in LinkedIn
  test campaigns, which the connector skips) keep their spend with NULL names and a
  NULL account.
- **Names are the current ones.** Entity tables keep one version per id, so a
  renamed campaign shows its new name on every past day.
- **Ad names are post titles.** LinkedIn creatives have no name field in the
  synced data; `ad_name` is the title of the promoted post, NULL where the post
  could not be read.
- **No demographic breakdown.** The connector syncs analytics pivoted by campaign
  and by creative only, so job title, seniority, company or country breakdowns
  cannot be built from this data.
- **Not run against a warehouse.** These models were checked for syntax and
  references only. Reconcile a week of spend, impressions, clicks and conversions
  per campaign against Campaign Manager (UTC days, same conversion columns) before
  relying on the output. The connector's `ad_analytics_by_campaign` table is a
  second independent source for the campaign totals.

## Schema notes

The public ERD and the connector agree on every column these models read. The ERD
lists the analytics `date` column as a date; the connector writes it as a
timestamp at midnight. Staging reads either form.

## Vendor docs

- LinkedIn Marketing API, Ads Reporting: <https://learn.microsoft.com/en-us/linkedin/marketing/integrations/ads-reporting/ads-reporting>
- LinkedIn Marketing API, metrics available (field definitions, UTC dates): <https://learn.microsoft.com/en-us/linkedin/marketing/integrations/ads-reporting/ads-reporting-schema>
