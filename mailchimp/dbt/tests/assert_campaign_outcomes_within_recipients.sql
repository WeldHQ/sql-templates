-- Bounces, opens and clicks can never exceed the number of people a campaign went to.
--
-- recipients is rebuilt from Mailchimp's "sent to" list and unique_opens comes from
-- Mailchimp's report. If unique opens exceed recipients, the sent-to stream is incomplete
-- for that campaign and every rate rebuilt from it is wrong.

SELECT campaign_id, recipients, hard_bounces, soft_bounces, unique_opens, unique_clickers
FROM {{ ref('core_mailchimp__campaign_performance') }}
WHERE recipients IS NOT NULL
  AND (
       COALESCE(hard_bounces, 0) + COALESCE(soft_bounces, 0) > recipients
    OR unique_opens > recipients
    OR unique_clickers > recipients
  )
