-- stg_sendgrid__spam_report
-- Thin wrapper over raw `spam_report`: SendGrid's spam_report suppression list,
-- recipients who marked a message as spam.
-- Casts, lower-cases the address, de-duplicates. No other logic.
--
-- Grain: email x created (the key of the raw table).
-- SendGrid removes an entry from the list when you delete the suppression. Rows already
-- synced stay in the warehouse, so this is a history of suppressions added, not the
-- list as it stands today.

SELECT
    LOWER(TRIM(CAST(email AS STRING)))      AS email,
    CAST(created AS TIMESTAMP)              AS created_at,
    CAST(ip AS STRING)                      AS sending_ip,
    'spam_report'                         AS suppression_type
FROM {{ source('sendgrid', 'spam_report') }}
WHERE email IS NOT NULL
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY LOWER(TRIM(CAST(email AS STRING))), created
    ORDER BY _weld_synced DESC
) = 1
