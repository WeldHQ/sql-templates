-- core_mixpanel_source__sessions
-- User sessions rebuilt from raw events, using Mixpanel's default timeout rule: a session
-- ends after 30 minutes without an event from that user.
--
-- Grain: one row per session (distinct_id x session start).
-- Depends on: staging.mixpanel_source.events
--
-- Mixpanel computes sessions at query time and does not export them, so they are rebuilt
-- here. A user's next event opens a new session when more than 30 minutes have passed
-- since their previous event, or when it falls on a new UTC day. The day break keeps
-- every session inside one daily row, which is how a sessions-per-day chart reads; a
-- session running across midnight is counted as two. Change `inactivity_minutes` to match
-- a custom timeout set in your project's session settings.
--
-- Users are the raw `distinct_id`, as in the other models: Mixpanel's identity merge is
-- not applied, so a session before login and one after are two sessions. Every event
-- counts, including automatic ones; filter event_name in `ordered` to narrow that.
-- `duration_seconds` is the time from first to last event, so a one-event session is 0.

WITH settings AS (
    SELECT 30 AS inactivity_minutes
),

ordered AS (
    SELECT
        e.distinct_id,
        e.event_name,
        e.event_at,
        DATE(e.event_at)                                                  AS event_date,
        LAG(e.event_at) OVER (
            PARTITION BY e.distinct_id, DATE(e.event_at) ORDER BY e.event_at, e.event_hash
        )                                                                 AS prior_event_at,
        e.event_hash
    FROM {{ ref('stg_mixpanel_source__events') }} e
    WHERE e.distinct_id IS NOT NULL
),

flagged AS (
    SELECT
        o.*,
        IF(o.prior_event_at IS NULL
           OR TIMESTAMP_DIFF(o.event_at, o.prior_event_at, SECOND) > s.inactivity_minutes * 60,
           1, 0)                                                          AS starts_session
    FROM ordered o
    CROSS JOIN settings s
),

numbered AS (
    SELECT
        *,
        SUM(starts_session) OVER (
            PARTITION BY distinct_id, event_date ORDER BY event_at, event_hash
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        )                                                                 AS session_seq
    FROM flagged
)

SELECT
    CONCAT(distinct_id, ':', CAST(event_date AS STRING), ':', CAST(session_seq AS STRING)) AS session_id,
    distinct_id,
    event_date                                                            AS session_date,
    session_seq                                                           AS session_number_of_day,
    MIN(event_at)                                                         AS session_started_at,
    MAX(event_at)                                                         AS session_ended_at,
    TIMESTAMP_DIFF(MAX(event_at), MIN(event_at), SECOND)                  AS duration_seconds,
    COUNT(*)                                                              AS events,
    COUNT(DISTINCT event_name)                                            AS distinct_event_names,
    ARRAY_AGG(event_name ORDER BY event_at, event_hash LIMIT 1)[OFFSET(0)] AS first_event_name
FROM numbered
GROUP BY distinct_id, event_date, session_seq
