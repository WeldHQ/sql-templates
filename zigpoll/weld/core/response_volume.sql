-- core.zigpoll.response_volume
-- Answers and respondents per poll per day.
-- Grain: day x zigpoll_account x poll. Dates are UTC days of the response's
-- `created_at`. Synthetic polls are excluded.
-- Depends on: staging.zigpoll.response, .poll
--
-- Zigpoll stores one response per participant per question, so there are two
-- different "how many" numbers and both are returned:
--   answers      every response row, i.e. questions answered;
--   respondents  distinct participants who answered at least one question.
-- `respondents` is a distinct count. It cannot be summed across days: a person
-- answering on Monday and Tuesday is one respondent for the week, two in the sum.
-- Recount from answer_detail for any period longer than a day.
--
-- Built on a day spine so a quiet day returns zeros instead of disappearing.
--
-- Poll views, opens and completions exist only as Zigpoll's lifetime counters on
-- the poll (staging.zigpoll.poll), with no dates, so there is no daily
-- participation rate. Divide totals against those counters at poll level instead.

WITH responses AS (
    SELECT
        r.zigpoll_account,
        r.poll_id,
        DATE(r.created_at) AS response_date,
        r.response_id,
        r.participant_id,
        r.completed_poll
    FROM {{staging.zigpoll.response}} r
    INNER JOIN {{staging.zigpoll.poll}} p
            ON p.zigpoll_account = r.zigpoll_account
           AND p.poll_id         = r.poll_id
    WHERE NOT p.is_synthetic
      AND r.created_at IS NOT NULL
),

day_spine AS (
    SELECT day
    FROM UNNEST(GENERATE_DATE_ARRAY(
        (SELECT MIN(response_date) FROM responses),
        CURRENT_DATE(),
        INTERVAL 1 DAY
    )) AS day
),

polls AS (
    SELECT DISTINCT r.zigpoll_account, r.poll_id, p.poll_title
    FROM responses r
    INNER JOIN {{staging.zigpoll.poll}} p
            ON p.zigpoll_account = r.zigpoll_account
           AND p.poll_id         = r.poll_id
),

daily AS (
    SELECT
        response_date AS day,
        zigpoll_account,
        poll_id,
        COUNT(*)                                             AS answers,
        COUNT(DISTINCT participant_id)                       AS respondents,
        -- Zigpoll flags a response with completed_poll when the participant
        -- reached the end of the poll; counted per participant.
        COUNT(DISTINCT IF(completed_poll, participant_id, NULL)) AS respondents_completed
    FROM responses
    GROUP BY 1, 2, 3
)

SELECT
    s.day,
    p.zigpoll_account,
    p.poll_id,
    p.poll_title,
    COALESCE(d.answers, 0)               AS answers,
    COALESCE(d.respondents, 0)           AS respondents,
    COALESCE(d.respondents_completed, 0) AS respondents_completed
FROM day_spine s
CROSS JOIN polls p
LEFT JOIN daily d
       ON d.day             = s.day
      AND d.zigpoll_account = p.zigpoll_account
      AND d.poll_id         = p.poll_id
