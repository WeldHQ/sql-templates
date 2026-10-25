# SQL templates

SQL models that rebuild source-system reports in your own warehouse, for 100
integrations.

Each integration ships both dialects:

- `weld/` — Weld transforms, `{{raw.source.table}}` refs
- `dbt/` — drop-in model files, `{{ source() }}` / `{{ ref() }}` refs

Most integrations are built in layers: `staging/` cleans and de-duplicates the raw
tables, `core/` holds the business logic, and `analytics/` is the table dashboards and
agents read. A few directories (`amazon-ads`, `amazon-mws`, `clickup`, `economic`,
`google-analytics-4`, `hubspot`, `instagram-business`, `intercom`, `xero`) hold
single-query reports instead.

The paid ads directories share one set of columns on their daily ad and campaign
models, and [`cross-channel-ads/`](cross-channel-ads/) stacks them into one paid
media table.

Every directory has a README that describes its models and what to check before
relying on them.

## Integrations

The model column lists the `core/` models (or the reports, for single-query
directories).

### E-commerce, fulfilment and payments

| Integration | Folder | Models |
|---|---|---|
| Adobe Commerce | [`adobe-commerce/`](adobe-commerce/) | inventory cover, product sales over time, sales over time |
| Adyen | [`adyen/`](adyen/) | authorisation rate, fees by payment method, payment lifecycle, settlement batches |
| Amazon Seller Central | [`amazon-seller-central/`](amazon-seller-central/) | ASIN profitability, inventory health, product sales over time, sales over time, settlement ledger, traffic and conversion |
| Amazon Seller Central (single-query reports) | [`amazon-mws/`](amazon-mws/) | monthly financial analysis, monthly inventory report, monthly order update tracking report, monthly returns analysis, monthly sales performance report, monthly shipping and delivery report |
| Amazon Vendor Central | [`amazon-vendor-central/`](amazon-vendor-central/) | forecast vs actuals, inventory health, sales by ASIN, sales over time |
| BigCommerce | [`bigcommerce/`](bigcommerce/) | product sales over time, sales over time |
| Cargoson | [`cargoson/`](cargoson/) | carrier costs by month, lane costs, shipments |
| Claimlane | [`claimlane/`](claimlane/) | B2B claim lines, B2B claims by month, B2C claim lines, B2C claims by month, B2C claims by product |
| DanDomain Webshop | [`dandomain-webshop/`](dandomain-webshop/) | product sales over time, sales over time |
| Klarna | [`klarna/`](klarna/) | daily settlement activity, fees by type, payout reconciliation |
| PayPal | [`paypal/`](paypal/) | balance reconciliation, daily balance activity, transactions |
| Salesforce Commerce Cloud | [`salesforce-commerce-cloud/`](salesforce-commerce-cloud/) | product sales over time, sales over time |
| ShipHero | [`shiphero/`](shiphero/) | fulfillment by day, order fulfillment, product returns by month, warehouse productivity |
| Shopify | [`shopify/`](shopify/) | product sales over time, sales by product, sales over time, SKU cost per day |
| TikTok Shop | [`tiktok-shop/`](tiktok-shop/) | product sales over time, sales over time, settlement ledger, shop performance |
| Traede | [`traede/`](traede/) | invoiced sales over time, order book, product sales, production order status |
| Walmart Marketplace | [`walmart/`](walmart/) | product sales over time, sales over time, settlement ledger |
| WooCommerce | [`woocommerce/`](woocommerce/) | customers, product sales over time, sales over time |

### Finance and billing

| Integration | Folder | Models |
|---|---|---|
| Chargebee | [`chargebee/`](chargebee/) | billing by month, MRR by customer month, MRR movements, recurring revenue lines |
| ChartMogul | [`chartmogul/`](chartmogul/) | customer MRR movements, MRR movements, plan metrics |
| e-conomic | [`economic/`](economic/) | invoice line items, order items |
| Forex | [`forex-v2/`](forex-v2/) | daily base rates, daily rates |
| Fortnox | [`fortnox/`](fortnox/) | general ledger, payables aging, profit and loss by month, receivables aging, trial balance |
| Microsoft Dynamics 365 Business Central | [`business-central/`](business-central/) | general ledger, profit and loss by month, receivables aging, trial balance by month |
| NetSuite | [`netsuite/`](netsuite/) | AR/AP aging, general ledger, profit and loss by month, trial balance |
| Netvisor | [`netvisor/`](netvisor/) | general ledger, payables aging, profit and loss by month, trial balance by month |
| QuickBooks Online | [`quickbooks/`](quickbooks/) | AR/AP aging, general ledger, profit and loss by month, trial balance |
| Recurly | [`recurly/`](recurly/) | billing by month, MRR by customer month, MRR movements, recurring revenue lines, subscription churn |
| Stripe | [`stripe/`](stripe/) | MRR active subscriptions, MRR normalization, MRR summary, MRR time series, subscription item |
| Workday Financial Management | [`workday-financial-management/`](workday-financial-management/) | AR aging, general ledger, profit and loss by month, trial balance |
| Xero | [`xero/`](xero/) | invoice entries report, journal entries report, monthly invoice summary report, monthly sales report, tracking details report |
| Younium | [`younium/`](younium/) | account CMRR, MRR movements, subscription MRR movements |

### Advertising

| Integration | Folder | Models |
|---|---|---|
| Amazon Ads | [`amazon-ads/`](amazon-ads/) | ad group report, ad report, campaign report, keyword report |
| Amazon Attribution | [`amazon-attribution/`](amazon-attribution/) | campaign performance daily, creative performance daily, product performance daily |
| Apple Ads | [`apple-ads/`](apple-ads/) | app performance daily, campaign performance daily |
| AppLovin | [`applovin/`](applovin/) | ad performance daily, campaign performance daily |
| Criteo | [`criteo/`](criteo/) | ad performance daily, campaign performance daily |
| Cross-channel paid media | [`cross-channel-ads/`](cross-channel-ads/) | campaign performance daily, channel performance daily |
| Daisycon | [`daisycon/`](daisycon/) | invoice costs monthly, invoices, media performance, publisher performance |
| Facebook Ads | [`facebook-ads/`](facebook-ads/) | ad performance daily, ad set performance daily, campaign performance daily, conversions by action type daily |
| Google Ads | [`google-ads/`](google-ads/) | ad performance daily, campaign performance daily, country performance daily, landing page performance daily |
| LinkedIn Ads | [`linkedin-ads/`](linkedin-ads/) | ad performance daily, campaign group performance daily, campaign performance daily |
| Microsoft Ads | [`microsoft-ads/`](microsoft-ads/) | account performance daily, ad group performance daily, ad performance daily, campaign performance daily |
| Pinterest Ads | [`pinterest-ads/`](pinterest-ads/) | ad performance daily, campaign country performance daily, campaign performance daily |
| Reddit Ads | [`reddit-ads/`](reddit-ads/) | ad performance daily, campaign performance daily |
| Snapchat Ads | [`snapchat-ads/`](snapchat-ads/) | ad performance daily, ad squad performance daily, campaign performance daily |
| TikTok Ads | [`tiktok-ads/`](tiktok-ads/) | ad group performance daily, ad performance daily, campaign performance daily |

### Organic social, search and web analytics

| Integration | Folder | Models |
|---|---|---|
| Facebook Pages | [`facebook-pages/`](facebook-pages/) | page performance daily, post performance |
| Google Analytics 4 | [`google-analytics-4/`](google-analytics-4/) | account report, campaign report, channel traffic overview, event performance, page path analysis, user activity overview |
| Google Business Profile | [`google-my-business-profile/`](google-my-business-profile/) | location performance daily, reviews monthly, search keywords monthly |
| Google Search Console | [`google-search-console/`](google-search-console/) | page performance daily, query page monthly, query performance daily, site performance daily |
| Instagram Business | [`instagram-business/`](instagram-business/) | engagement metric analysis, growth analysis, media insights deep dive, media performance report, profile overview report, user engagement and outreach report |
| LinkedIn Pages | [`linkedin-pages/`](linkedin-pages/) | follower demographics, follower growth daily, page performance daily |
| Sprout Social | [`sprout-social/`](sprout-social/) | case resolution, case volume daily, message volume daily, team activity daily |
| TikTok Organic | [`tiktok-organic/`](tiktok-organic/) | profile performance daily, video performance |
| YouTube Analytics | [`youtube-analytics/`](youtube-analytics/) | channel performance daily, traffic sources daily, video performance daily, viewer demographics daily |

### CRM, sales, support and surveys

| Integration | Folder | Models |
|---|---|---|
| Calendly | [`calendly/`](calendly/) | bookings by source, meetings by day, scheduled events |
| Freshdesk | [`freshdesk/`](freshdesk/) | agent performance by month, CSAT by month, first response by month, ticket lifecycle, ticket volume by day |
| Gong | [`gong/`](gong/) | calls, rep call activity by day, rep interaction stats by week, scorecard scores by rep |
| Gorgias | [`gorgias/`](gorgias/) | agent performance by month, response times by month, ticket lifecycle, ticket volume by day, voice calls by day |
| Grin | [`grin/`](grin/) | campaign performance, conversions by day, creator campaign performance |
| HighLevel | [`go-high/`](go-high/) | opportunity outcomes monthly, payments daily, pipeline snapshot |
| HubSpot | [`hubspot-v2/`](hubspot-v2/) | company 360, deal activity, deal flow by month, deal pipeline, deal stage history, rep activity |
| HubSpot (single-query reports) | [`hubspot/`](hubspot/) | calls by owner, closed lost deals by owner, closed won deals amount by owner, closed won deals by owner, conversion from contacts to deals by owner, deals by deal stage, emails by owner, meetings by owner, new companies by month, new contacts by month, new deals by month, tasks completed by owner |
| Intercom | [`intercom/`](intercom/) | monthly conversation tags, monthly conversations by team, monthly conversations rating, monthly ticket by state, monthly ticket resolution time, monthly tickets by team |
| Medallia | [`medallia/`](medallia/) | answer detail, feedback volume, NPS by unit month, topic volume |
| Qualtrics | [`qualtrics/`](qualtrics/) | answer detail, distribution performance, NPS by month, response volume |
| Salesforce | [`salesforce/`](salesforce/) | lead funnel daily, opportunity pipeline, opportunity stage history, pipeline flow daily, rep activity |
| Typeform | [`typeform/`](typeform/) | answer detail, response volume, score summary |
| Zendesk | [`zendesk/`](zendesk/) | agent performance by month, response times by month, ticket lifecycle, ticket volume by day |
| Zigpoll | [`zigpoll/`](zigpoll/) | answer detail, attribution by answer, response volume, score summary |
| Zoho CRM | [`zoho-crm/`](zoho-crm/) | account 360, deal flow by month, deal pipeline, rep activity |

### Email, messaging and product analytics

| Integration | Folder | Models |
|---|---|---|
| Gmail | [`gmail/`](gmail/) | correspondents monthly, email volume daily, messages, response times |
| Iterable | [`iterable/`](iterable/) | email campaign performance, email performance daily |
| Klaviyo | [`klaviyo/`](klaviyo/) | events flow campaign report, monthly campaign status breakdown by list, monthly flow events, monthly user engagement per campaign |
| Mailchimp | [`mailchimp/`](mailchimp/) | audience growth daily, audience summary, campaign performance |
| Mixpanel | [`mixpanel-source/`](mixpanel-source/) | active users daily, events daily, funnel conversion daily, sessions |
| QRFY | [`qrfy/`](qrfy/) | QR codes, scans by location and device, scans daily |
| SendGrid | [`sendgrid/`](sendgrid/) | category stats daily, email stats daily, mailbox provider stats daily, suppressions daily |
| Twilio | [`twilio/`](twilio/) | calls daily, message errors daily, messaging daily |

### Developer tools, app stores and platforms

| Integration | Folder | Models |
|---|---|---|
| App Store Connect | [`app-store-connect/`](app-store-connect/) | downloads and deletions, product page conversion, ratings and reviews, sales and proceeds, usage and stability |
| Auth0 | [`auth0/`](auth0/) | logins by application, monthly active users, tenant activity daily, user signups |
| Google Play | [`google-play/`](google-play/) | earnings monthly, installs daily, stability by app version, store listing conversion, subscriptions daily |
| LaunchDarkly | [`launchdarkly/`](launchdarkly/) | context activity, flag health by project, flag inventory |
| Linear | [`linear/`](linear/) | cycle progress, issue cycle time, issue flow, open backlog |
| PagerDuty | [`pager-duty/`](pager-duty/) | incident response daily, open incidents, responder load daily |
| WordPress | [`wordpress/`](wordpress/) | content inventory, publishing cadence |

### Work management, HR, hospitality and inventory

| Integration | Folder | Models |
|---|---|---|
| Asana | [`asana/`](asana/) | open task workload, project overview, task completion |
| ClickUp | [`clickup/`](clickup/) | monthly time tracking and billing report, task checklist progress, task dependency analysis, team overview report, user activity and performance report |
| eSmiley | [`esmiley/`](esmiley/) | food waste by area month, food waste daily, registration point tree |
| Fourth | [`fourth/`](fourth/) | department location, labour cost daily, labour vs sales, sales forecast accuracy, staffing accuracy, weekly budget vs actual |
| Harvest | [`harvest/`](harvest/) | invoice aging, project budget, time report, weekly utilization |
| HiBob | [`hibob/`](hibob/) | employee roster, headcount monthly, time off daily |
| monday.com | [`monday/`](monday/) | board activity, item assignments, status changes |
| Notion | [`notion/`](notion/) | database pages, pages created, status breakdown |
| OpenWeather | [`openweather/`](openweather/) | daily forecast, daily weather |
| SevenRooms | [`seven-rooms/`](seven-rooms/) | booking lead time, covers by day, guest feedback |
| Sona | [`sona/`](sona/) | absence daily, paid hours daily, shift coverage daily |
| Toast | [`toast/`](toast/) | labor by job, labor vs sales, menu item sales, sales summary |
| Toast Analytics | [`toast-analytics/`](toast-analytics/) | daily sales, labor by job, menu item performance, payouts |
| Unleashed | [`unleashed/`](unleashed/) | open sales orders, sales margin, stock position |

## Notes

- Written for BigQuery; adapt functions for other engines.
- Files are named for what they do. The model name inside keeps its source prefix
  (`shopify_sales_over_time`) so table names stay unambiguous in one schema.
- `dbt/` folders are model files, not runnable projects. Copy them into your own
  project and repoint the refs. Tests are named `assert_<source>__<check>`, so several
  integrations can share one project.
- **Treat every model as unverified until you have reconciled it against the source
  system.** Scope limits and validation status are in each file header.
