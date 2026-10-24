-- Promoters, passives and detractors must add up to the valid NPS answers, and no
-- NPS question should carry scores outside 0 to 10.
--
-- A row with invalid_scores > 0 almost always means the question's recode values
-- were edited in Qualtrics, so the exported value is no longer the 0 to 10 score.
-- Fix the recodes in the survey, or map them in nps_by_month.

SELECT
    month,
    qualtrics_account,
    survey_id,
    question_id,
    answers,
    promoters + passives + detractors AS bucketed_answers,
    invalid_scores
FROM {{ ref('core_qualtrics__nps_by_month') }}
WHERE promoters + passives + detractors <> answers
   OR invalid_scores > 0
