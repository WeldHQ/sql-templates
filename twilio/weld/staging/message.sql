-- staging.twilio.message
-- Thin wrapper over raw `message`: one row per SMS, MMS or WhatsApp message on the
-- account. Casts, converts price to a positive cost, de-duplicates.
--
-- Grain: message_sid.
-- Every sync reads the last two days again to catch status changes, so a
-- message can arrive more than once; the latest copy is kept.
-- Twilio reports `price` as a negative number (a charge to you) in `price_unit` currency,
-- and leaves it empty until the carrier has priced the message. `cost` flips the sign.
-- `body` is not carried through: message content is personal data, and none of the
-- reports need it.

SELECT
    CAST(sid AS STRING)                                         AS message_sid,
    CAST(account_sid AS STRING)                                 AS account_sid,
    CAST(messaging_service_sid AS STRING)                       AS messaging_service_sid,
    LOWER(CAST(direction AS STRING))                            AS direction,
    LOWER(CAST(status AS STRING))                               AS status,
    CAST(`from` AS STRING)                                      AS from_number,
    CAST(`to` AS STRING)                                        AS to_number,
    CAST(date_created AS TIMESTAMP)                             AS created_at,
    CAST(date_sent AS TIMESTAMP)                                AS sent_at,
    CAST(date_updated AS TIMESTAMP)                             AS updated_at,
    SAFE_CAST(num_segments AS INT64)                            AS segments,
    SAFE_CAST(num_media AS INT64)                               AS media_count,
    CAST(error_code AS INT64)                                   AS error_code,
    CAST(error_message AS STRING)                               AS error_message,
    -1 * SAFE_CAST(price AS NUMERIC)                            AS cost,
    UPPER(CAST(price_unit AS STRING))                           AS currency
FROM {{raw.twilio.message}}
QUALIFY ROW_NUMBER() OVER (PARTITION BY sid ORDER BY date_updated DESC, _weld_synced DESC) = 1
