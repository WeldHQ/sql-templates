-- core.twilio.messaging_daily
-- Messaging volume, delivery and spend per day: the numbers on Twilio's Messaging
-- Insights overview.
--
-- Grain: one row per day (UTC) x account x messaging service x direction x currency.
-- Depends on: staging.twilio.message, .messaging_service
--
-- Day is the send time, or the creation time for messages that were never sent (queued,
-- failed before sending, scheduled). `direction` is `inbound`, `outbound-api`,
-- `outbound-reply` or `outbound-call`.
--
-- Delivery rate follows Messaging Insights: delivered over outbound messages that reached
-- a final state (delivered, undelivered, failed, read). `sent` means Twilio handed the
-- message to the carrier and never got a receipt back, which is common on some routes; it
-- is counted separately and left out of the rate's denominator. The rate is per row:
-- sum the counts and divide again when you aggregate.
--
-- Segments are what Twilio bills SMS on: a long message is several segments.
--
-- `messaging_service_name` is the service's current name, looked up after aggregation so
-- the join cannot change any count. Messages sent straight from a number have no service.

WITH daily AS (
    SELECT
        DATE(COALESCE(sent_at, created_at))                         AS date,
        account_sid,
        messaging_service_sid,
        direction,
        currency,

        COUNT(*)                                                    AS messages,
        SUM(segments)                                               AS segments,
        COUNTIF(media_count > 0)                                    AS messages_with_media,

        COUNTIF(status IN ('delivered', 'read'))                    AS delivered,
        COUNTIF(status = 'read')                                    AS read,
        COUNTIF(status = 'sent')                                    AS sent_no_receipt,
        COUNTIF(status = 'undelivered')                             AS undelivered,
        COUNTIF(status = 'failed')                                  AS failed,
        COUNTIF(status IN ('received', 'receiving'))                AS received,
        COUNTIF(status IN ('queued', 'accepted', 'scheduled', 'sending')) AS in_flight,
        COUNTIF(status = 'canceled')                                AS canceled,

        SAFE_DIVIDE(
            COUNTIF(status IN ('delivered', 'read')),
            COUNTIF(status IN ('delivered', 'read', 'undelivered', 'failed')))  AS delivery_rate,

        SUM(cost)                                                   AS cost,
        COUNTIF(cost IS NULL AND status NOT IN ('failed', 'canceled')) AS messages_not_yet_priced
    FROM {{staging.twilio.message}}
    GROUP BY 1, 2, 3, 4, 5
)

SELECT
    d.*,
    ms.messaging_service_name
FROM daily d
LEFT JOIN {{staging.twilio.messaging_service}} ms
       ON ms.messaging_service_sid = d.messaging_service_sid
