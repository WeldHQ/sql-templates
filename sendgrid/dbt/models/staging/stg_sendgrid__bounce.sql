-- stg_sendgrid__bounce
-- Thin wrapper over raw `bounce`: SendGrid's bounce suppression list, addresses that
-- hard-bounced.
-- Casts, lower-cases the address, de-duplicates. No other logic.
--
-- Grain: email x created (the key of the raw table).
-- SendGrid removes an entry from the list when you delete the suppression. Rows already
-- synced stay in the warehouse, so this is a history of suppressions added, not the
-- list as it stands today.

SELECT
    LOWER(TRIM(CAST(email AS STRING)))      AS email,
    CAST(created AS TIMESTAMP)              AS created_at,
    CAST(reason AS STRING)                  AS reason,
    CAST(status AS STRING)                  AS status,
    'bounce'                              AS suppression_type
FROM {{ source('sendgrid', 'bounce') }}
WHERE email IS NOT NULL
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY LOWER(TRIM(CAST(email AS STRING))), created
    ORDER BY _weld_synced DESC
) = 1
