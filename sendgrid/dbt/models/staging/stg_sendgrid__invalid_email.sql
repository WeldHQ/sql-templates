-- stg_sendgrid__invalid_email
-- Thin wrapper over raw `invalid_email`: SendGrid's invalid_email suppression list,
-- addresses SendGrid rejected as malformed or non-existent.
-- Casts, lower-cases the address, de-duplicates. No other logic.
--
-- Grain: email x created (the connector's own key for this stream).
-- SendGrid removes an entry from the list when you delete the suppression. Rows already
-- synced stay in the warehouse, so this is a history of suppressions added, not the
-- list as it stands today.

SELECT
    LOWER(TRIM(CAST(email AS STRING)))      AS email,
    CAST(created AS TIMESTAMP)              AS created_at,
    CAST(reason AS STRING)                  AS reason,
    'invalid_email'                       AS suppression_type
FROM {{ source('sendgrid', 'invalid_email') }}
WHERE email IS NOT NULL
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY LOWER(TRIM(CAST(email AS STRING))), created
    ORDER BY _weld_synced DESC
) = 1
