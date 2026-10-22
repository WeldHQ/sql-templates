-- stg_typeform__response_answer_choice
-- Thin wrapper over raw `response_answer_choice`. One row per selected choice on a
-- multiple choice, dropdown or picture choice answer. A single-select answer has one
-- row; a multi-select answer has one row per option ticked.
--
-- An "Other" write-in has no choice id; its typed text is in `choice_text`.

SELECT
    'account_1'                       AS typeform_account,
    CAST(form_id AS STRING)           AS form_id,
    CAST(response_token AS STRING)    AS response_token,
    CAST(field_id AS STRING)          AS field_id,
    CAST(choice_id AS STRING)         AS choice_id,
    CAST(choice_text AS STRING)       AS choice_text
FROM {{ source('typeform', 'response_answer_choice') }}
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY form_id, response_token, field_id, COALESCE(choice_id, choice_text)
    ORDER BY _weld_synced DESC
) = 1
