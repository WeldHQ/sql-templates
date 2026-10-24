-- core.qualtrics.nps_by_month
-- Net Promoter Score per NPS question per month.
-- Grain: month x qualtrics_account x survey x question. Months are UTC calendar
-- months of `recorded_at`. Only questions Qualtrics defines as NPS (type MC,
-- selector NPS), and only non-test, non-spam responses. Recorded but unfinished
-- responses count when they answered the NPS question, as in Qualtrics' reports.
-- Depends on: core.qualtrics.answer_detail
--
-- Promoters score 9 to 10, passives 7 to 8, detractors 0 to 6, and NPS is the
-- share of promoters minus the share of detractors, times 100. The bucket counts
-- are returned, so a quarter or a year is recomputed from summed counts. Never
-- average the monthly NPS values: that weights a month with ten answers the same
-- as one with a thousand.
--
-- THE SCORE IS THE EXPORTED VALUE, which for an NPS question is the choice's
-- recode. Qualtrics' default NPS recodes are 0 to 10. If someone has changed the
-- recode values on a question, its scores are wrong here and in Qualtrics' own
-- NPS widget alike; `invalid_scores` counts values outside 0 to 10 so it shows up.

WITH nps_answers AS (
    SELECT
        qualtrics_account,
        survey_id,
        survey_name,
        question_id,
        question_text,
        DATE_TRUNC(recorded_date, MONTH) AS month,
        response_number AS score
    FROM {{core.qualtrics.answer_detail}}
    WHERE question_type = 'MC'
      AND selector      = 'NPS'
      AND NOT is_test_or_spam
      AND response_value IS NOT NULL
),

scored AS (
    SELECT
        *,
        score IS NOT NULL AND score BETWEEN 0 AND 10 AND score = TRUNC(score) AS is_valid_score
    FROM nps_answers
)

SELECT
    month,
    qualtrics_account,
    survey_id,
    survey_name,
    question_id,
    question_text,
    COUNTIF(is_valid_score)                             AS answers,
    COUNTIF(is_valid_score AND score >= 9)              AS promoters,
    COUNTIF(is_valid_score AND score BETWEEN 7 AND 8)   AS passives,
    COUNTIF(is_valid_score AND score <= 6)              AS detractors,
    100 * SAFE_DIVIDE(
        COUNTIF(is_valid_score AND score >= 9) - COUNTIF(is_valid_score AND score <= 6),
        COUNTIF(is_valid_score)
    ) AS nps,
    SUM(IF(is_valid_score, score, NULL))                AS total_score,
    AVG(IF(is_valid_score, score, NULL))                AS avg_score,
    COUNTIF(NOT is_valid_score)                         AS invalid_scores
FROM scored
GROUP BY 1, 2, 3, 4, 5, 6
