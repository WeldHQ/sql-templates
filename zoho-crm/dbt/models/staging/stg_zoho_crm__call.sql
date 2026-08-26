-- stg_zoho_crm__call
-- Thin wrapper over raw `call`. Casts, renames, parses the duration string.
--
-- NO PARENT LINK. Same as task: Zoho's Calls module has What_Id / Who_Id, the
-- connector does not sync them. owner_id is the only key.
--
-- DURATION IS A STRING, NOT A NUMBER. `call_duration` arrives as text with one
-- colon. Zoho's API reference documents the field as hh:mm; the CRM UI shows
-- mm:ss for short calls, and there is no Call_Duration_in_seconds column on this
-- stream to disambiguate. This model parses it as the DOCUMENTED hh:mm.
--
-- Reconcile call_duration_minutes against one call of known length before
-- reporting on it. If your org turns out to emit mm:ss, divide by 60.
-- tests/assert_call_duration_parses.sql guards the shape, not the unit.

SELECT
    'org_1'                                 AS zoho_org,
    CAST(id AS STRING)                      AS call_id,
    NULLIF(TRIM(CAST(subject AS STRING)), '')   AS subject,
    NULLIF(TRIM(CAST(call_type AS STRING)), '') AS call_type,
    CAST(call_start_time AS TIMESTAMP)      AS call_start_time,
    CAST(call_duration AS STRING)           AS call_duration_raw,
    CASE
        WHEN REGEXP_CONTAINS(CAST(call_duration AS STRING), r'^\s*\d+:\d{1,2}\s*$')
        THEN SAFE_CAST(SPLIT(TRIM(CAST(call_duration AS STRING)), ':')[OFFSET(0)] AS INT64) * 60
           + SAFE_CAST(SPLIT(TRIM(CAST(call_duration AS STRING)), ':')[OFFSET(1)] AS INT64)
    END                                     AS call_duration_minutes,
    CAST(owner_id AS STRING)                AS owner_id,
    CAST(created_time AS TIMESTAMP)         AS created_time,
    CAST(modified_time AS TIMESTAMP)        AS modified_time
FROM {{ source('zoho_crm', 'call') }}
