-- stg_hubspot_v2__engagement
-- Thin wrapper over raw `engagement`: calls, emails, meetings, notes and tasks
-- logged in HubSpot. Grain: one row per engagement.
--
-- `metadata` is the activity's detail as JSON and differs by type. The fields
-- parsed here are the ones HubSpot documents for that type: call duration in
-- milliseconds and call status, task status, meeting outcome.
--
-- Inactive engagements (deleted in HubSpot) are dropped.
--
-- deal_ids is a native array column in the raw table.

SELECT
    'portal_1'                                                AS hubspot_portal,
    CAST(engagement_id AS STRING)                             AS engagement_id,
    UPPER(type)                                               AS engagement_type,
    CAST(owner_id AS STRING)                                  AS owner_id,
    -- When the activity happened (the call was made, the meeting held), as opposed
    -- to created_at, which is when it was logged.
    CAST(timestamp AS TIMESTAMP)                              AS occurred_at,
    CAST(created_at AS TIMESTAMP)                             AS created_at,
    SAFE_CAST(JSON_VALUE(metadata, '$.durationMilliseconds') AS INT64) / 60000.0 AS call_duration_minutes,
    UPPER(JSON_VALUE(metadata, '$.status'))                   AS status,
    UPPER(JSON_VALUE(metadata, '$.meetingOutcome'))           AS meeting_outcome,
    -- The deals the activity is associated with, as HubSpot sends them.
    -- Unpacked to one row per deal in staging.hubspot_v2.engagement_deal.
    deal_ids
FROM {{ source('hubspot_v2', 'engagement') }}
WHERE COALESCE(active, TRUE)
