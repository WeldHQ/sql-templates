-- staging.twilio.call
-- Thin wrapper over raw `call`: one row per call leg on the account. Casts, converts
-- price to a positive cost, de-duplicates.
--
-- Grain: call_sid (one leg).
-- A call your application forwards with <Dial> is two legs: the parent (for example
-- inbound) and a child (`outbound-dial`) with `parent_call_sid` set. Both are billed and
-- both are rows here.
-- The connector only fetches calls once they have ended, so in-progress calls are absent.
-- `duration` is in seconds. `price` is negative (a charge to you); `cost` flips the sign.

SELECT
    CAST(sid AS STRING)                                         AS call_sid,
    CAST(parent_call_sid AS STRING)                             AS parent_call_sid,
    CAST(account_sid AS STRING)                                 AS account_sid,
    CAST(phone_number_sid AS STRING)                            AS phone_number_sid,
    LOWER(CAST(direction AS STRING))                            AS direction,
    LOWER(CAST(status AS STRING))                               AS status,
    LOWER(CAST(answered_by AS STRING))                          AS answered_by,
    CAST(`from` AS STRING)                                      AS from_number,
    CAST(`to` AS STRING)                                        AS to_number,
    CAST(start_time AS TIMESTAMP)                               AS started_at,
    CAST(end_time AS TIMESTAMP)                                 AS ended_at,
    CAST(duration AS INT64)                                     AS duration_seconds,
    CAST(queue_time AS INT64)                                   AS queue_time_ms,
    -1 * CAST(price AS NUMERIC)                                 AS cost,
    UPPER(CAST(price_unit AS STRING))                           AS currency
FROM {{raw.twilio.call}}
QUALIFY ROW_NUMBER() OVER (PARTITION BY sid ORDER BY date_updated DESC, _weld_synced DESC) = 1
