-- stg_gmail__profile
-- Thin wrapper over raw `profile`: the connected mailbox's own address and Gmail's
-- message and thread totals.
--
-- Grain: one row per mailbox (the latest sync).

SELECT
    LOWER(CAST(email_address AS STRING))    AS mailbox_address,
    CAST(messages_total AS INT64)           AS messages_total,
    CAST(threads_total AS INT64)            AS threads_total
FROM {{ source('gmail', 'profile') }}
QUALIFY ROW_NUMBER() OVER (ORDER BY _weld_synced DESC) = 1
