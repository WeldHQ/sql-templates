-- One row per response x question x selected choice.
--
-- A duplicate here doubles a bar in every answer distribution. The usual causes
-- are a question id appearing twice in form_field, or a second account unioned
-- into staging without changing the typeform_account label.

SELECT
    typeform_account,
    form_id,
    response_token,
    field_id,
    COALESCE(choice_id, choice_text) AS choice_key,
    COUNT(*) AS rows_for_answer
FROM {{ ref('core_typeform__answer_detail') }}
GROUP BY 1, 2, 3, 4, 5
HAVING COUNT(*) > 1
