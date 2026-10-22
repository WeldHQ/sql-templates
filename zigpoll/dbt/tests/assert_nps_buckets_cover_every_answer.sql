-- On a slide classified as a 0 to 10 scale, promoters, passives and detractors must
-- add up to every scored answer, and every answer must be scorable.
--
-- A row here means an answer value that is not a whole number from 0 to 10 reached
-- an NPS slide, usually because the slide's options were edited after it
-- collected answers.

SELECT
    month,
    zigpoll_account,
    poll_id,
    slide_id,
    answers,
    promoters + passives + detractors AS bucketed_answers,
    unscored_answers
FROM {{ ref('core_zigpoll__score_summary') }}
WHERE is_nps_scale
  AND (promoters + passives + detractors <> answers OR unscored_answers > 0)
