-- Every question nps_by_unit_month treats as NPS should be scored 0 to 10.
--
-- The model picks NPS questions by name ("recommend"), which is a guess about your
-- instance. A row here is a question that was picked but whose answers are mostly
-- outside 0 to 10: a "would you recommend us to a colleague, yes/no" question, or a
-- five-point scale. Replace the rule in nps_by_unit_month with an explicit list of
-- question ids.
--
-- It also fails when the rule picks nothing at all, which almost always means your
-- likelihood-to-recommend question is named differently.

WITH by_question AS (
    SELECT
        medallia_account,
        question_id,
        question_name,
        SUM(answers)          AS answers,
        SUM(excluded_answers) AS excluded_answers
    FROM {{ ref('core_medallia__nps_by_unit_month') }}
    GROUP BY 1, 2, 3
)

SELECT *
FROM by_question
WHERE excluded_answers > answers

UNION ALL

SELECT
    'none'                              AS medallia_account,
    'no NPS question matched the rule'  AS question_id,
    CAST(NULL AS STRING)                AS question_name,
    0                                   AS answers,
    0                                   AS excluded_answers
FROM (SELECT 1)
WHERE NOT EXISTS (SELECT 1 FROM by_question)
