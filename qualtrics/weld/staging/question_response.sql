-- staging.qualtrics.question_response
-- Thin wrapper over raw `question_response`. One row per response x question x
-- matrix row (sub question) x selected value. Long format already: a multi-select
-- answer arrives as one row per selected choice, numbered by `response_index`,
-- and a matrix answer as one row per row of the matrix.
--
-- `response_value` is what Qualtrics exports as the value: the choice's recode for
-- a choice question, the typed text for a text entry. `response_label` is the
-- choice text the respondent saw. Both are strings.
--
-- There is no survey_id on this table. Response ids are unique across surveys, so
-- core gets the survey through survey_response.

SELECT
    'account_1'                       AS qualtrics_account,
    CAST(response_id AS STRING)       AS response_id,
    CAST(question_id AS STRING)       AS question_id,
    CAST(sub_question_key AS STRING)  AS sub_question_key,
    CAST(response_index AS INT64)     AS response_index,
    CAST(response AS STRING)          AS response_value,
    CAST(label AS STRING)             AS response_label
FROM {{raw.qualtrics.question_response}}
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY response_id, question_id, sub_question_key, response_index
    ORDER BY _weld_synced DESC
) = 1
