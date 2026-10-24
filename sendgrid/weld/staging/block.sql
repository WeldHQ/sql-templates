-- staging.sendgrid.block
-- Thin wrapper over raw `block`: SendGrid's block suppression list, addresses whose
-- receiving server blocked a message (not a hard bounce).
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
    'block'                               AS suppression_type
FROM {{raw.sendgrid.block}}
WHERE email IS NOT NULL
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY LOWER(TRIM(CAST(email AS STRING))), created
    ORDER BY _weld_synced DESC
) = 1
