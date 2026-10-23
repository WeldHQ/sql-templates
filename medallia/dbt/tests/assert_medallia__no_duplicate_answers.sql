-- One row per feedback record x question x position.
--
-- The option join is on field and option id together; if an instance ever reuses
-- an option id within a field, answers would double here and in every NPS count.

SELECT
    medallia_account,
    feedback_id,
    question_id,
    position,
    COUNT(*) AS rows_for_answer
FROM {{ ref('core_medallia__answer_detail') }}
GROUP BY 1, 2, 3, 4
HAVING COUNT(*) > 1
