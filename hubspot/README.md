# HubSpot templates

SQL reports over Weld's HubSpot connector. BigQuery.

| Model | Report | What it returns |
|---|---|---|
| [`weld/core/calls_by_owner.sql`](weld/core/calls_by_owner.sql) · [dbt](dbt/models/core/core_hubspot__calls_by_owner.sql) | Calls by owner | Retrieves the number of calls made by each owner in HubSpot and displays it alongside their first and last name. It uses a left join to connect the engagements and owners tables and filters the results to only include calls. The output is grouped by owner. |
| [`weld/core/closed_lost_deals_by_owner.sql`](weld/core/closed_lost_deals_by_owner.sql) · [dbt](dbt/models/core/core_hubspot__closed_lost_deals_by_owner.sql) | Closed lost deals by owner | Retrieves the number of closed lost deals by owner from HubSpot and orders them by the highest number of deals. It uses a left join to match the owner ID from the deals table to the owners table and concatenates the first and last name of the owner for readability. |
| [`weld/core/closed_won_deals_amount_by_owner.sql`](weld/core/closed_won_deals_amount_by_owner.sql) · [dbt](dbt/models/core/core_hubspot__closed_won_deals_amount_by_owner.sql) | Closed won deals amount by owner | Retrieves the total amount of closed won deals for each owner in HubSpot and orders them in descending order. |
| [`weld/core/closed_won_deals_by_owner.sql`](weld/core/closed_won_deals_by_owner.sql) · [dbt](dbt/models/core/core_hubspot__closed_won_deals_by_owner.sql) | Closed won deals by owner | Retrieves the number of closed won deals by owner from HubSpot and orders them in descending order based on the number of deals. |
| [`weld/core/conversion_from_contacts_to_deals_by_owner.sql`](weld/core/conversion_from_contacts_to_deals_by_owner.sql) · [dbt](dbt/models/core/core_hubspot__conversion_from_contacts_to_deals_by_owner.sql) | Conversion from contacts to deals by owner | Converts contacts to deals by owner in HubSpot, displaying the owner's name, the number of contacts they have, the number of deals they have, and the conversion rate between the two. It uses left joins to connect the necessary tables and groups the results by owner. |
| [`weld/core/deals_by_deal_stage.sql`](weld/core/deals_by_deal_stage.sql) · [dbt](dbt/models/core/core_hubspot__deals_by_deal_stage.sql) | Deals by deal stage | Retrieves the number of deals in each stage of the sales pipeline from HubSpot and groups them by their respective stage labels. |
| [`weld/core/emails_by_owner.sql`](weld/core/emails_by_owner.sql) · [dbt](dbt/models/core/core_hubspot__emails_by_owner.sql) | Emails by owner | Retrieves the number of emails sent by each owner in HubSpot by joining the engagements and owners tables and grouping the results by owner. |
| [`weld/core/meetings_by_owner.sql`](weld/core/meetings_by_owner.sql) · [dbt](dbt/models/core/core_hubspot__meetings_by_owner.sql) | Meetings by owner | Retrieves the number of meetings organized by each owner in HubSpot and displays it alongside their first and last name. It uses a left join to connect the engagements and owners tables and filters the results to only include meetings. The output is grouped by owner. |
| [`weld/core/new_companies_by_month.sql`](weld/core/new_companies_by_month.sql) · [dbt](dbt/models/core/core_hubspot__new_companies_by_month.sql) | New companies by month | Retrieves a list of new companies created each month from the HubSpot integration and groups them by month. The results are ordered by month. |
| [`weld/core/new_contacts_by_month.sql`](weld/core/new_contacts_by_month.sql) · [dbt](dbt/models/core/core_hubspot__new_contacts_by_month.sql) | New contacts by month | Retrieves the number of new contacts added to HubSpot each month and groups them by month. It uses the date_trunc function to extract the month from the createdAt field and orders the results by month. |
| [`weld/core/new_deals_by_month.sql`](weld/core/new_deals_by_month.sql) · [dbt](dbt/models/core/core_hubspot__new_deals_by_month.sql) | New deals by month | Retrieves the number of new deals created each month from HubSpot and organizes them by month. |
| [`weld/core/tasks_completed_by_owner.sql`](weld/core/tasks_completed_by_owner.sql) · [dbt](dbt/models/core/core_hubspot__tasks_completed_by_owner.sql) | Tasks completed by owner | Retrieves the number of completed tasks for each owner in HubSpot, using a left join between the engagements and owners tables. The result includes the owner's first and last name, as well as the count of completed tasks. |

## Where these come from

These started as the templates in the weld.app template library. Each one was
published as a single query rather than a layered model set. Every query was
reviewed when it moved here and corrected where it was wrong; the corrections
are listed under Changes from the website version. The layout:

- Queries that hold report logic sit in `weld/core/`, each with a `SELECT *`
  passthrough in `weld/analytics/` for dashboards to bind to.
- Most queries read the raw tables directly, so there is no staging layer of
  cast-and-rename wrappers like the one in [`shopify/`](../shopify/).
- None of them has been reconciled against the source system. Treat every model
  as a starting point and check the output before relying on it.
- `dbt/` holds the same SQL with `{{ source() }}` / `{{ ref() }}` refs. No dbt
  tests ship with these models.

## Changes from the website version

Corrected in review:

- `core/tasks_completed_by_owner` reads the task status with the JSONPath `'$.status'`; the website version's `' .status'` was invalid.
- `core/conversion_from_contacts_to_deals_by_owner` counts distinct contacts and deals, so a contact with several deals counts once, and divides with `safe_divide`. The owner join compares IDs as strings, which works whatever type each side lands as.

## Required tables

| Model | Raw tables |
|---|---|
| `core/calls_by_owner` | `hubspot.engagements`, `hubspot.owners` |
| `core/closed_lost_deals_by_owner` | `hubspot.deals`, `hubspot.owners` |
| `core/closed_won_deals_amount_by_owner` | `hubspot.deals`, `hubspot.owners` |
| `core/closed_won_deals_by_owner` | `hubspot.deals`, `hubspot.owners` |
| `core/conversion_from_contacts_to_deals_by_owner` | `hubspot.contact_deal`, `hubspot.contacts`, `hubspot.deals`, `hubspot.owners` |
| `core/deals_by_deal_stage` | `hubspot.deals`, `hubspot.pipeline_stage` |
| `core/emails_by_owner` | `hubspot.engagements`, `hubspot.owners` |
| `core/meetings_by_owner` | `hubspot.engagements`, `hubspot.owners` |
| `core/new_companies_by_month` | `hubspot.companies` |
| `core/new_contacts_by_month` | `hubspot.contacts` |
| `core/new_deals_by_month` | `hubspot.deals` |
| `core/tasks_completed_by_owner` | `hubspot.engagements`, `hubspot.owners` |

## Models

### Calls by owner

`weld/core/calls_by_owner.sql`

This template allows you to easily track the number of calls made by each owner in
your organization. The SQL code selects the first and last name of each owner, along
with the total number of calls they have made. This information is obtained by
joining the engagements table with the owners table, and filtering for calls only.
The resulting output is a table that displays the name of each owner and the number
of calls they have made. This information can be used to identify top performers,
track progress over time, and make data-driven decisions about your sales strategy.
With the Calls by Owner SQL template, you can gain valuable insights into your sales
team's performance and optimize your sales process for maximum efficiency.

### Closed lost deals by owner

`weld/core/closed_lost_deals_by_owner.sql`

This SQL model allows you to quickly and easily see which sales representatives are
losing the most deals, and how many deals they are losing. By joining the HubSpot
deals and owners tables, this SQL template creates a list of all closed lost deals,
grouped by the sales representative who was responsible for the deal. This
information can be used to identify areas where sales representatives may need
additional training or support, or to identify patterns in the types of deals that
are being lost. The output of this SQL template is a table that shows the name of
the sales representative and the number of closed lost deals they have had, sorted
in descending order by the number of deals. This SQL template is a valuable tool for
any business that wants to improve their sales performance and increase their
revenue.

### Closed won deals amount by owner

`weld/core/closed_won_deals_amount_by_owner.sql`

This SQL model allows you to easily track the amount of closed won deals by owner,
giving you valuable insights into the performance of your sales team. By joining the
HubSpot deals and owners tables, this SQL model creates a list of all closed won
deals and the corresponding owner's name. The results are then grouped by owner and
sorted by the total amount of closed won deals, allowing you to quickly identify
your top-performing salespeople. This SQL template is an excellent way to measure
the success of your sales team and identify areas for improvement.

### Closed won deals by owner

`weld/core/closed_won_deals_by_owner.sql`

This SQL model allows you to easily track the number of closed won deals by each
owner in your organization. By running this SQL, you can quickly gain insights into
which sales reps are performing the best and which ones may need additional support.
The SQL code uses a left join to combine data from the HubSpot deals and owners
tables, and then filters the results to only show deals that have been marked as
"closedwon". The output of the SQL is a table that displays the name of each deal
owner and the number of closed won deals they have. This information can be used to
identify top performers, set sales goals, and optimize your sales process.

### Conversion from contacts to deals by owner

`weld/core/conversion_from_contacts_to_deals_by_owner.sql`

This SQL template allows you to analyze the conversion rate of contacts to deals
based on the owner of the contact. By integrating with HubSpot, this SQL pulls data
from the contacts, contact_deal, deals, and owners tables to calculate the number of
contacts and deals associated with each owner, as well as the conversion rate. The
output of this SQL provides valuable insights into which owners are most successful
at converting contacts to deals, and can help identify areas for improvement in your
sales process. With this information, you can optimize your sales strategy and
increase your overall conversion rate.

### Deals by deal stage

`weld/core/deals_by_deal_stage.sql`

This SQL model allows you to easily track the number of deals in each stage of your
sales pipeline. By selecting the pipeline_stage.label as deal_stage and counting the
number of deals, you can quickly see how many deals are in each stage of your
pipeline. This information can be incredibly useful for sales managers who want to
identify bottlenecks in their sales process and make data-driven decisions to
improve their team's performance. The SQL code is integrated with HubSpot, so you
can easily access your data and generate insights that will help you close more
deals. With the Deals by Deal Stage SQL template, you can take your sales pipeline
management to the next level and drive more revenue for your business.

### Emails by owner

`weld/core/emails_by_owner.sql`

This SQL model allows you to easily retrieve the number of emails sent by each owner
in your HubSpot account. By joining the engagements and owners tables, this SQL
template creates a comprehensive report that includes the first and last name of
each owner, as well as the total number of emails they have sent. This information
can be used to gain insights into the performance of your sales team, identify top
performers, and optimize your email marketing strategy. With the Emails by Owner SQL
template, you can quickly and easily analyze your email engagement data and make
data-driven decisions to improve your business.

### Meetings by owner

`weld/core/meetings_by_owner.sql`

This SQL model allows you to easily track the number of meetings each owner has had
with clients or prospects. By selecting the owner's first and last name and counting
the number of meetings they have had, you can quickly see which owners are the most
active in meeting with clients. This information can be used to identify top-
performing salespeople or to ensure that all owners are meeting with clients
regularly. The SQL code is easy to use and can be integrated seamlessly with your
existing HubSpot data. Simply input the code and run the query to get a clear
picture of your team's meeting activity. With the Meetings by Owner SQL template,
you can gain valuable insights into your sales team's performance and make data-
driven decisions to improve your business.

### New companies by month

`weld/core/new_companies_by_month.sql`

This SQL model allows you to easily track the number of new companies that have been
added to your CRM each month. By using the date_trunc function, the SQL template
groups the companies by month, providing you with a clear and concise overview of
your company's growth over time. This information can be incredibly useful for
businesses looking to track their progress and identify trends in their customer
acquisition. With the New Companies by Month SQL template, you can gain valuable
insights into your company's growth and make data-driven decisions to help your
business succeed.

### New contacts by month

`weld/core/new_contacts_by_month.sql`

This SQL model allows you to easily track the number of new contacts added to your
HubSpot database each month. By using the date_trunc function, the SQL groups
contacts by the month they were created, providing a clear picture of how your
contact list is growing over time. This information can be used to identify trends
in your lead generation efforts, and to make data-driven decisions about how to
allocate your marketing resources. With the New Contacts by Month SQL template, you
can gain valuable insights into the effectiveness of your marketing campaigns and
make informed decisions about how to optimize your lead generation efforts.

### New deals by month

`weld/core/new_deals_by_month.sql`

This SQL model allows you to quickly and easily analyze your sales data by grouping
deals by the month they were created. By using the date_trunc function, the SQL
template aggregates all deals created in a given month and returns the total number
of deals for each month. This information can be incredibly useful for identifying
trends in your sales data, such as which months are the busiest or slowest for your
business. With this insight, you can adjust your sales strategy accordingly and
optimize your sales performance. The New Deals by Month SQL template is a must-have
for any business looking to gain a deeper understanding of their sales data and
improve their bottom line.

### Tasks completed by owner

`weld/core/tasks_completed_by_owner.sql`

This SQL model allows you to easily track the number of completed tasks for each
owner in your organization. By joining the engagements and owners tables, the SQL
code creates a list of owners and the number of tasks they have completed. This
information can be used to identify top performers, track progress towards goals,
and identify areas where additional support may be needed. The output of this SQL
code is a table that displays the owner's name and the number of tasks they have
completed. This SQL template is a valuable tool for any business looking to optimize
their sales process and improve team performance.
