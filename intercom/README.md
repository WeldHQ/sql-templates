# Intercom templates

SQL reports over Weld's Intercom connector. BigQuery.

| Model | Report | What it returns |
|---|---|---|
| [`weld/core/monthly_conversation_tags.sql`](weld/core/monthly_conversation_tags.sql) · [dbt](dbt/models/core/core_intercom__monthly_conversation_tags.sql) | Monthly Tags By Conversation | This SQL template extracts monthly tags by conversation from the Intercom integration. It uses a common table expression (CTE) to join the conversation and conversation_tag tables, and then retrieves the month, tag name, and tag count for each conversation. The results are grouped by month and tag name, and ordered by month in descending order. |
| [`weld/core/monthly_conversations_by_team.sql`](weld/core/monthly_conversations_by_team.sql) · [dbt](dbt/models/core/core_intercom__monthly_conversations_by_team.sql) | Monthly Conversations By Team | Extracts monthly conversation data by team from the Intercom integration. It selects the month, team ID, team name, and ticket count from the conversation table. It then joins the conversation table with the team table and groups the results by month, team ID, and team name, ordering them by month and ticket count in descending order. |
| [`weld/core/monthly_conversations_rating.sql`](weld/core/monthly_conversations_rating.sql) · [dbt](dbt/models/core/core_intercom__monthly_conversations_rating.sql) | Monthly Average Conversations Rating | Extracts the monthly average rating for conversations from the Intercom integration. It selects the truncated month and calculates the average rating for conversations that have a non-null rating value. The results are grouped by month and ordered in descending order. |
| [`weld/core/monthly_ticket_by_state.sql`](weld/core/monthly_ticket_by_state.sql) · [dbt](dbt/models/core/core_intercom__monthly_ticket_by_state.sql) | Count of Tickets By State | Extracts the count of tickets grouped by month and ticket state from the Intercom integration. It uses the `date_trunc` function to truncate the `created_at` column to the month level. The result is then ordered by month in descending order, followed by the ticket count in descending order. |
| [`weld/core/monthly_ticket_resolution_time.sql`](weld/core/monthly_ticket_resolution_time.sql) · [dbt](dbt/models/core/core_intercom__monthly_ticket_resolution_time.sql) | Monthly Ticket Resolution Time | Extracts the monthly ticket resolution time for a specific integration (intercom). It selects the month, team ID, team name, and average resolution time in days. It joins the ticket and team tables, filters for resolved tickets, groups the results by month and team, and sorts them in descending order by month and ascending order by average resolution time. |
| [`weld/core/monthly_tickets_by_team.sql`](weld/core/monthly_tickets_by_team.sql) · [dbt](dbt/models/core/core_intercom__monthly_tickets_by_team.sql) | Monthly Tickets By Team | Extracts monthly ticket data for each team, including the team ID, team name, and the count of tickets. It uses the Intercom integration and joins the ticket and team tables based on the team assignee ID. The results are grouped by month, team ID, and team name, and ordered by month and ticket count in descending order. |

## Where these come from

These are the templates from the weld.app template library, moved here
unchanged apart from the notes below. Each one was published as a single query
rather than a layered model set, so:

- Queries that hold report logic sit in `weld/core/`, each with a `SELECT *`
  passthrough in `weld/analytics/` for dashboards to bind to.
- Most queries read the raw tables directly, so there is no staging layer of
  cast-and-rename wrappers like the one in [`shopify/`](../shopify/).
- None of them has been reconciled against the source system. Treat every model
  as a starting point and check the output before relying on it.
- `dbt/` holds the same SQL with `{{ source() }}` / `{{ ref() }}` refs. No dbt
  tests ship with these models.

## Required tables

| Model | Raw tables |
|---|---|
| `core/monthly_conversation_tags` | `intercom.conversation_tag`, `intercom.conversation`, `intercom.tag` |
| `core/monthly_conversations_by_team` | `intercom.conversation`, `intercom.team` |
| `core/monthly_conversations_rating` | `intercom.conversation` |
| `core/monthly_ticket_by_state` | `intercom.ticket` |
| `core/monthly_ticket_resolution_time` | `intercom.team`, `intercom.ticket` |
| `core/monthly_tickets_by_team` | `intercom.team`, `intercom.ticket` |

## Models

### Monthly Tags By Conversation

`weld/core/monthly_conversation_tags.sql`

The SQL template "Get Monthly Tags By Conversation" is designed to retrieve monthly
tag information from the Intercom integration. This SQL model allows you to analyze
and understand the distribution of tags used in conversations over time.

### Monthly Conversations By Team

`weld/core/monthly_conversations_by_team.sql`

The SQL template "Get Monthly Conversations By Team" is designed to retrieve
information about the number of conversations per month, grouped by team. This
template is integrated with Intercom, a customer messaging platform.

### Monthly Average Conversations Rating

`weld/core/monthly_conversations_rating.sql`

The SQL template "Get Monthly Average Conversations Rating" is designed to retrieve
the average rating of conversations on a monthly basis. It utilizes the integration
with Intercom, a customer messaging platform. The SQL code begins by selecting the
month and calculating the average conversation rating using the `date_trunc` and
`avg` functions respectively. It then specifies the table
`{{raw.intercom.conversation}}` from which the data is retrieved. The `where` clause
ensures that only conversations with a non-null rating are considered. The results
are grouped by month and ordered in descending order.

### Count of Tickets By State

`weld/core/monthly_ticket_by_state.sql`

The SQL template "Count of Tickets By State" is designed to retrieve data from the
Intercom integration. This SQL code calculates the number of tickets grouped by
their state and the month they were created. The output includes three columns:
"month" (representing the truncated creation date), "ticket_state" (representing the
state of the ticket), and "ticket_count" (representing the count of tickets in each
state for a given month).

### Monthly Ticket Resolution Time

`weld/core/monthly_ticket_resolution_time.sql`

The SQL template "Get Monthly Ticket Resolution Time" is designed to retrieve data
related to the average resolution time of tickets on a monthly basis. This template
is integrated with Intercom, a customer messaging platform, to fetch ticket
information.

### Monthly Tickets By Team

`weld/core/monthly_tickets_by_team.sql`

The SQL template "Get Monthly Tickets By Team" is designed to retrieve monthly
ticket data from the Intercom integration. This SQL query allows you to analyze
ticket distribution and activity within different teams over time.

## Known issues

Found while moving the templates here. The SQL is kept as published; fix these
before running the affected models.

- `core/monthly_tickets_by_team`: `team_assignee_id = te.id` has no cast, while both sibling queries cast it to string (likely).
