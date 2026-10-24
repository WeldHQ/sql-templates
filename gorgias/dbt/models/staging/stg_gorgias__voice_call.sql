-- stg_gorgias__voice_call
-- Thin wrapper over raw `voice_call`. One row per phone call handled by Gorgias
-- Voice. Casts and renames only.
--
-- duration is in seconds. Gorgias documents direction, status and
-- termination_status as strings without publishing the full set of values, so
-- they are passed through lower-cased rather than mapped.

SELECT
    'account_1'                                       AS gorgias_account,
    CAST(id AS STRING)                                AS call_id,
    CAST(ticket_id AS STRING)                         AS ticket_id,
    CAST(customer_id AS STRING)                       AS customer_id,
    CAST(queue_id AS STRING)                          AS queue_id,
    CAST(integration_id AS STRING)                    AS integration_id,
    LOWER(NULLIF(TRIM(CAST(direction AS STRING)), ''))          AS direction,
    LOWER(NULLIF(TRIM(CAST(status AS STRING)), ''))             AS status,
    LOWER(NULLIF(TRIM(CAST(termination_status AS STRING)), '')) AS termination_status,
    CAST(last_answered_by_agent_id AS STRING)         AS answered_by_agent_id,
    CAST(initiated_by_agent_id AS STRING)             AS initiated_by_agent_id,
    NULLIF(TRIM(CAST(answered_by_external_number AS STRING)), '') AS answered_by_external_number,
    CAST(duration AS INT64)                           AS duration_seconds,
    COALESCE(CAST(has_voicemail AS BOOL), FALSE)      AS has_voicemail,
    COALESCE(CAST(has_call_recording AS BOOL), FALSE) AS has_call_recording,
    CAST(started_datetime AS TIMESTAMP)               AS started_at,
    CAST(created_datetime AS TIMESTAMP)               AS created_at,
    CAST(updated_datetime AS TIMESTAMP)               AS updated_at
FROM {{ source('gorgias', 'voice_call') }}
WHERE id IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY id ORDER BY updated_datetime DESC) = 1
