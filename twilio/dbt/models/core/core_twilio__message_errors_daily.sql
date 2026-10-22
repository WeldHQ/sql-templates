-- core_twilio__message_errors_daily
-- Failed and undelivered messages by Twilio error code: the Errors view in Messaging
-- Insights. The first place to look when delivery rate drops.
--
-- Grain: one row per day (UTC) x account x messaging service x error code.
-- Depends on: staging.twilio.message
--
-- Common codes: 30003 unreachable handset, 30005 unknown number, 30006 landline or
-- unreachable carrier, 30007 carrier filtering (often spam), 30008 unknown error,
-- 21610 recipient replied STOP. The full list is in Twilio's error dictionary, linked in
-- the README. `example_error_message` is one of the messages Twilio returned for that
-- code on that day.

SELECT
    DATE(COALESCE(sent_at, created_at))                         AS date,
    account_sid,
    messaging_service_sid,
    error_code,
    MAX(error_message)                                          AS example_error_message,
    COUNT(*)                                                    AS messages,
    COUNTIF(status = 'failed')                                  AS failed,
    COUNTIF(status = 'undelivered')                             AS undelivered,
    COUNT(DISTINCT to_number)                                   AS distinct_recipients
FROM {{ ref('stg_twilio__message') }}
WHERE error_code IS NOT NULL
  AND error_code != 0
GROUP BY 1, 2, 3, 4
