-- staging.zoho_crm.event
-- Thin wrapper over raw `event` (Zoho's Meetings module). Casts, renames, derives
-- duration from the start and end timestamps.
--
-- NO PARENT LINK. Same as task and call: owner_id is the only foreign key.

SELECT
    'org_1'                                 AS zoho_org,
    CAST(id AS STRING)                      AS event_id,
    NULLIF(TRIM(CAST(event_title AS STRING)), '') AS event_title,
    CAST(start_date_time AS TIMESTAMP)      AS start_date_time,
    CAST(end_date_time AS TIMESTAMP)        AS end_date_time,
    -- Unlike call, event carries both ends, so duration is computed rather than
    -- parsed out of a string and the unit is unambiguous.
    TIMESTAMP_DIFF(
        CAST(end_date_time AS TIMESTAMP),
        CAST(start_date_time AS TIMESTAMP),
        MINUTE
    )                                       AS duration_minutes,
    NULLIF(TRIM(CAST(location AS STRING)), '') AS location,
    CAST(owner_id AS STRING)                AS owner_id,
    CAST(created_time AS TIMESTAMP)         AS created_time,
    CAST(modified_time AS TIMESTAMP)        AS modified_time
FROM {{raw.zoho_crm.event}}
