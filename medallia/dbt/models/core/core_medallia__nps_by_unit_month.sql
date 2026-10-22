-- core_medallia__nps_by_unit_month
-- Net Promoter Score per unit per month for your likelihood-to-recommend questions.
-- Grain: month x medallia_account x unit x question. Months are UTC calendar
-- months of `responded_at`.
-- Depends on: core.medallia.answer_detail, staging.medallia.field_meta_data
--
-- WHICH QUESTION IS NPS is instance configuration in Medallia, not a fixed field
-- id. The `nps_questions` CTE below picks questions whose name mentions
-- "recommend". Check what it selects with tests/assert_nps_questions_are_0_to_10.sql
-- and replace the rule with an explicit list of question ids (for example
-- `WHERE field_id IN ('q_ltr')`) once you know yours. This is the one edit most
-- instances need.
--
-- Promoters score 9 to 10, passives 7 to 8, detractors 0 to 6; NPS is the share of
-- promoters minus the share of detractors, times 100, from counts. Roll up by
-- summing the counts and recomputing, never by averaging monthly NPS values: that
-- weights a unit with five answers the same as one with five hundred.

WITH nps_questions AS (
    SELECT medallia_account, field_id AS question_id
    FROM {{ ref('stg_medallia__field_meta_data') }}
    WHERE LOWER(field_name) LIKE '%recommend%'
      AND COALESCE(data_type, '') <> 'COMMENT'
),

scored AS (
    SELECT
        a.medallia_account,
        DATE_TRUNC(a.responded_date, MONTH) AS month,
        a.unit_identifier,
        a.unit_name,
        a.question_id,
        a.question_name,
        a.score,
        a.score IS NOT NULL AND a.score BETWEEN 0 AND 10 AND a.score = TRUNC(a.score) AS is_valid_score
    FROM {{ ref('core_medallia__answer_detail') }} a
    INNER JOIN nps_questions q
            ON q.medallia_account = a.medallia_account
           AND q.question_id      = a.question_id
    WHERE a.responded_at IS NOT NULL
)

SELECT
    month,
    medallia_account,
    unit_identifier,
    unit_name,
    question_id,
    question_name,
    COUNTIF(is_valid_score)                           AS answers,
    COUNTIF(is_valid_score AND score >= 9)            AS promoters,
    COUNTIF(is_valid_score AND score BETWEEN 7 AND 8) AS passives,
    COUNTIF(is_valid_score AND score <= 6)            AS detractors,
    100 * SAFE_DIVIDE(
        COUNTIF(is_valid_score AND score >= 9) - COUNTIF(is_valid_score AND score <= 6),
        COUNTIF(is_valid_score)
    ) AS nps,
    SUM(IF(is_valid_score, score, NULL))              AS total_score,
    AVG(IF(is_valid_score, score, NULL))              AS avg_score,
    -- Answers that are not a whole number from 0 to 10, such as "N/A" options.
    -- Excluded from NPS, as Medallia excludes them.
    COUNTIF(NOT is_valid_score)                       AS excluded_answers
FROM scored
GROUP BY 1, 2, 3, 4, 5, 6
