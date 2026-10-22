-- core_gong__calls
-- Every Gong call with its rep, participants, talk time, Gong's interaction
-- statistics and the CRM records it is linked to, on one row.
--
-- Grain: one row per gong_account x call.
-- Depends on: staging.gong.call, .call_participant, .call_speaker,
--             .call_interaction, .call_crm_object, .user
--
-- Every child table is aggregated to call grain in its own CTE BEFORE the joins.
-- Joining participants and speakers raw would multiply talk time by the number of
-- participants.
--
-- THE REP is the call's primary_user_id: the Gong user who owns the call (usually
-- the host). It is the dimension Gong's own Team Stats use.
--
-- TWO KINDS OF TALK RATIO:
--   rep_talk_ratio / company_talk_ratio   computed here from per-speaker talk
--       seconds: the rep's (or everyone internal's) share of all talk time on the
--       call. Always 0 to 1, and auditable from call_speaker.
--   gong_talk_ratio and the other gong_* columns   Gong's own interaction
--       statistics, passed through as Gong reports them. Use these when the number
--       has to match the Gong UI; see the README on units.

WITH participants AS (
    SELECT
        gong_account,
        call_id,
        COUNT(*)                              AS participants,
        COUNTIF(affiliation = 'Internal')     AS internal_participants,
        COUNTIF(affiliation = 'External')     AS external_participants
    FROM {{ ref('stg_gong__call_participant') }}
    GROUP BY 1, 2
),

speaker_affiliation AS (
    -- A speaker counts as internal if Gong tied them to a user or the matching
    -- participant is affiliated Internal.
    SELECT
        s.gong_account,
        s.call_id,
        s.speaker_id,
        s.user_id,
        s.talk_time_seconds,
        (s.user_id IS NOT NULL OR p.affiliation = 'Internal') AS is_internal
    FROM {{ ref('stg_gong__call_speaker') }} s
    LEFT JOIN (
        -- One participant per speaker id, so the join cannot fan out.
        SELECT gong_account, call_id, speaker_id, ANY_VALUE(affiliation) AS affiliation
        FROM {{ ref('stg_gong__call_participant') }}
        WHERE speaker_id IS NOT NULL
        GROUP BY 1, 2, 3
    ) p
        ON  p.gong_account = s.gong_account
        AND p.call_id      = s.call_id
        AND p.speaker_id   = s.speaker_id
),

talk AS (
    SELECT
        sa.gong_account,
        sa.call_id,
        SUM(sa.talk_time_seconds)                                   AS total_talk_seconds,
        SUM(IF(sa.is_internal, sa.talk_time_seconds, 0))            AS company_talk_seconds,
        SUM(IF(sa.user_id = c.primary_user_id, sa.talk_time_seconds, 0)) AS rep_talk_seconds,
        COUNT(*)                                                    AS speakers
    FROM speaker_affiliation sa
    JOIN {{ ref('stg_gong__call') }} c
        ON  c.gong_account = sa.gong_account
        AND c.call_id      = sa.call_id
    GROUP BY 1, 2
),

stats AS (
    SELECT
        gong_account,
        call_id,
        MAX(IF(stat_key = 'talk_ratio',             stat_value, NULL)) AS gong_talk_ratio,
        MAX(IF(stat_key = 'longest_monologue',      stat_value, NULL)) AS gong_longest_monologue,
        MAX(IF(stat_key = 'longest_customer_story', stat_value, NULL)) AS gong_longest_customer_story,
        MAX(IF(stat_key = 'interactivity',          stat_value, NULL)) AS gong_interactivity,
        MAX(IF(stat_key = 'patience',               stat_value, NULL)) AS gong_patience,
        MAX(IF(stat_key = 'question_rate',          stat_value, NULL)) AS gong_question_rate
    FROM {{ ref('stg_gong__call_interaction') }}
    GROUP BY 1, 2
),

crm AS (
    SELECT
        gong_account,
        call_id,
        COUNT(*)                                                         AS crm_objects,
        STRING_AGG(DISTINCT IF(LOWER(object_type) IN ('account', 'company'), object_id, NULL), ', ')
                                                                         AS crm_account_ids,
        STRING_AGG(DISTINCT IF(LOWER(object_type) IN ('opportunity', 'deal'), object_id, NULL), ', ')
                                                                         AS crm_deal_ids
    FROM {{ ref('stg_gong__call_crm_object') }}
    GROUP BY 1, 2
)

SELECT
    c.gong_account,
    c.call_id,
    c.workspace_id,
    c.title,
    c.started_at,
    DATE(c.started_at)                                        AS call_date,
    c.scheduled_at,
    c.duration_seconds,
    c.duration_seconds / 60.0                                 AS duration_minutes,
    c.scope,
    c.scope = 'External'                                      AS is_external,
    c.direction,
    c.system,
    c.media,
    c.purpose,
    c.language,
    c.is_private,
    c.call_outcome_category,
    c.call_outcome_name,
    c.sdr_disposition,

    c.primary_user_id,
    u.user_name                                               AS rep_name,
    u.email_address                                           AS rep_email,
    u.manager_id                                              AS rep_manager_id,
    m.user_name                                               AS rep_manager_name,
    u.is_active                                               AS rep_is_active,

    COALESCE(p.participants, 0)                               AS participants,
    COALESCE(p.internal_participants, 0)                      AS internal_participants,
    COALESCE(p.external_participants, 0)                      AS external_participants,

    t.speakers,
    t.total_talk_seconds,
    t.company_talk_seconds,
    t.rep_talk_seconds,
    SAFE_DIVIDE(t.rep_talk_seconds, t.total_talk_seconds)     AS rep_talk_ratio,
    SAFE_DIVIDE(t.company_talk_seconds, t.total_talk_seconds) AS company_talk_ratio,

    s.gong_talk_ratio,
    s.gong_longest_monologue,
    s.gong_longest_customer_story,
    s.gong_interactivity,
    s.gong_patience,
    s.gong_question_rate,
    c.questions_asked_by_company,
    c.questions_asked_by_others,

    COALESCE(cr.crm_objects, 0)                               AS crm_objects,
    cr.crm_account_ids,
    cr.crm_deal_ids,

    c.gong_url
FROM {{ ref('stg_gong__call') }} c
LEFT JOIN participants p
    ON  p.gong_account = c.gong_account AND p.call_id = c.call_id
LEFT JOIN talk t
    ON  t.gong_account = c.gong_account AND t.call_id = c.call_id
LEFT JOIN stats s
    ON  s.gong_account = c.gong_account AND s.call_id = c.call_id
LEFT JOIN crm cr
    ON  cr.gong_account = c.gong_account AND cr.call_id = c.call_id
LEFT JOIN {{ ref('stg_gong__user') }} u
    ON  u.gong_account = c.gong_account AND u.user_id = c.primary_user_id
LEFT JOIN {{ ref('stg_gong__user') }} m
    ON  m.gong_account = u.gong_account AND m.user_id = u.manager_id
