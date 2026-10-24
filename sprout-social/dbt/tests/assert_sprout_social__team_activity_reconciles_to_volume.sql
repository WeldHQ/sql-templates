-- Messages sent by Sprout users, summed over users, must equal the messages sent
-- from Sprout in the volume model, day by day and per profile.
-- Returns zero rows when they agree.

WITH team AS (
    SELECT date_day, COALESCE(customer_profile_id, 'none') AS customer_profile_id, SUM(messages_sent) AS sent
    FROM {{ ref('core_sprout_social__team_activity_daily') }}
    GROUP BY 1, 2
),

volume AS (
    SELECT date_day, COALESCE(customer_profile_id, 'none') AS customer_profile_id, SUM(sent_from_sprout) AS sent
    FROM {{ ref('core_sprout_social__message_volume_daily') }}
    GROUP BY 1, 2
)

SELECT
    COALESCE(t.date_day, v.date_day)                       AS date_day,
    COALESCE(t.customer_profile_id, v.customer_profile_id) AS customer_profile_id,
    t.sent AS team_sent,
    v.sent AS volume_sent
FROM team t
FULL OUTER JOIN volume v USING (date_day, customer_profile_id)
WHERE COALESCE(t.sent, 0) != COALESCE(v.sent, 0)
