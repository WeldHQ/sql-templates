-- stg_gong__call
-- Thin wrapper over raw `call`: one row per recorded or imported call. Casts,
-- renames, normalises enums. No business logic.
--
-- `duration` is in seconds. `started` and `scheduled` are UTC timestamps.
-- `scope` is Gong's classification of who was on the call: 'External' (at least one
-- participant outside your company), 'Internal' or 'Unknown'. `direction` is
-- 'Inbound', 'Outbound', 'Conference' or 'Unknown'. `system` is the recording or
-- telephony source (Zoom, Teams, a dialer and so on).
--
-- Deduped on id. The connector re-reads its whole window weekly to pick up edits
-- to older calls, and the destination merges on id, so this is belt and braces.
--
-- Single Gong instance. To add another, UNION ALL a second block below pointing at
-- that connector with a different gong_account label. Keep it in staging so the
-- core models never have to know how many accounts there are.

SELECT
    'account_1'                                       AS gong_account,
    CAST(id AS STRING)                                AS call_id,
    CAST(workspace_id AS STRING)                      AS workspace_id,
    CAST(primary_user_id AS STRING)                   AS primary_user_id,
    NULLIF(TRIM(CAST(title AS STRING)), '')           AS title,
    CAST(started AS TIMESTAMP)                        AS started_at,
    CAST(scheduled AS TIMESTAMP)                      AS scheduled_at,
    CAST(duration AS INT64)                           AS duration_seconds,
    INITCAP(NULLIF(CAST(scope AS STRING), ''))        AS scope,
    INITCAP(NULLIF(CAST(direction AS STRING), ''))    AS direction,
    NULLIF(CAST(system AS STRING), '')                AS system,
    NULLIF(CAST(media AS STRING), '')                 AS media,
    NULLIF(CAST(purpose AS STRING), '')               AS purpose,
    NULLIF(CAST(language AS STRING), '')              AS language,
    COALESCE(CAST(is_private AS BOOL), FALSE)         AS is_private,
    NULLIF(CAST(sdr_disposition AS STRING), '')       AS sdr_disposition,
    NULLIF(CAST(content_call_outcome_category AS STRING), '') AS call_outcome_category,
    NULLIF(CAST(content_call_outcome_name AS STRING), '')     AS call_outcome_name,
    CAST(interaction_questions_company_count AS INT64)        AS questions_asked_by_company,
    CAST(interaction_questions_non_company_count AS INT64)    AS questions_asked_by_others,
    CAST(url AS STRING)                               AS gong_url
FROM {{ source('gong', 'call') }}
WHERE id IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY id ORDER BY _weld_synced DESC) = 1
