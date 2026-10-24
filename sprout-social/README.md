# Sprout Social templates

Inbox and customer care reporting from Sprout Social: message volume per profile
and message type, what the team sent from Sprout, and case volume and time to
close. BigQuery.

Weld connector: **Sprout Social**.

| Model | Recreates | Grain |
|---|---|---|
| [`weld/core/message_volume_daily.sql`](weld/core/message_volume_daily.sql) · [dbt](dbt/models/core/core_sprout_social__message_volume_daily.sql) | Inbox volume: received, sent, sent from Sprout, turned into cases | day × profile × post type |
| [`weld/core/team_activity_daily.sql`](weld/core/team_activity_daily.sql) · [dbt](dbt/models/core/core_sprout_social__team_activity_daily.sql) | Team report, volume side: messages each user sent from Sprout | day × user × profile |
| [`weld/core/case_resolution.sql`](weld/core/case_resolution.sql) · [dbt](dbt/models/core/core_sprout_social__case_resolution.sql) | Case detail with time to close or time open | case |
| [`weld/core/case_volume_daily.sql`](weld/core/case_volume_daily.sql) · [dbt](dbt/models/core/core_sprout_social__case_volume_daily.sql) | Cases opened and closed, median and 90th percentile time to close | day × group × queue × case type × priority |

## What is not here: post and profile analytics

Sprout Social is mostly used for organic analytics: followers, impressions,
engagements and video views per profile and per post. The Weld connector does not
sync Sprout's analytics endpoints. It syncs profiles, groups, users, tags, cases and
messages, and messages carry no metrics. So these templates cover inbox and care
reporting, which the synced data supports, and nothing here reports reach or
engagement. Organic performance per network is better taken from that network's own
connector where Weld has one.

## Layers

```
raw.sprout_social.*        ELT output, untouched
  ↓
weld/staging/*.sql         4 thin wrappers: cast, rename, de-duplicate
  ↓
weld/core/*.sql            the reports, all the business logic lives here
  ↓
weld/analytics/*.sql       BI-facing contracts, deliberately thin
```

Analytics models are `SELECT *` on purpose: dashboards bind to them, so core can be
changed without breaking anything downstream. `dbt/` holds the same models with dbt
refs, generated from the Weld versions; see [dbt/README.md](dbt/README.md).

Weld references map to folder paths, so `{{staging.sprout_social.message}}` expects
the model in a `staging > sprout_social` folder. Mirror that structure or adjust the
refs.

## Required tables

| Model | Raw tables |
|---|---|
| message volume daily | `message`, `profile` |
| team activity daily | `message`, `profile` |
| case resolution | `cases`, `group`, `message` |
| case volume daily | the same, through `case_resolution` |

## Notes

- **Messages are everything the profiles sent or received** that Sprout collected:
  posts, comments, mentions, direct messages, reviews and replies. `post_type` is
  Sprout's network-specific type (for example `INSTAGRAM_COMMENT`),
  `post_category` the network-neutral version.
- **Sent versus received is derived.** A message counts as sent when its author is
  the connected profile itself (`from.guid` equals `profile_guid`). Sprout does not
  return its own `sent` flag on this endpoint. Check one profile's split against the
  Smart Inbox before relying on it.
- **Sent from Sprout** means a Sprout user sent the message from inside Sprout, so
  it carries the user. Posts published natively on the network are sent, but not
  sent from Sprout.
- **Days are UTC.** Every timestamp is stored in UTC. Sprout's own
  reports use the timezone set on your account, so day boundaries can differ.
- **Messages are read once.** New messages are picked up by creation time, so a
  message's case link or tags that change later are not updated. Cases are picked
  up again whenever they change, so their status and close time stay current.
- **Time to close** runs from creation to the last close. A reopened case counts
  its full span. Sprout's own reports may measure differently (for example
  excluding time on hold); compare a week before using the numbers for targets.
- **No response times.** The synced message fields do not link a reply to the
  message it answers, so first-response time cannot be computed.
- **Not run against a warehouse.** These models were checked for syntax and
  references only. Reconcile a week of message volume per profile and of cases
  opened and closed against Sprout's reports (same timezone) before relying on the
  output.

## Schema notes

There is no public ERD for this connector; every column used here comes from the
schema Weld syncs. Nested fields are flattened with underscores
(`from.guid` becomes `from_guid`, `internal.sent_by.id` becomes
`internal_sent_by_id`), and list fields (`assigned_to`, `internal_tags`, `hashtags`)
arrive as JSON strings. The `sent` column exists on `message` but is always empty,
so sent versus received is derived instead (see Notes). Messages carry no customer or group id; the customer comes from `profile`
and the group of a case from `group`.

## Vendor docs

- [Sprout Social API](https://api.sproutsocial.com/docs/)
