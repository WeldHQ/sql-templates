-- stg_qualtrics__sub_question
-- Thin wrapper over raw `sub_question`. One row per row of a matrix question (the
-- statements a respondent rates), so a matrix answer can be labelled.

SELECT
    'account_1'                                  AS qualtrics_account,
    CAST(survey_id AS STRING)                    AS survey_id,
    CAST(question_id AS STRING)                  AS question_id,
    CAST(key AS STRING)                          AS sub_question_key,
    NULLIF(TRIM(CAST(choice_text AS STRING)), '') AS sub_question_text
FROM {{ source('qualtrics', 'sub_question') }}
QUALIFY ROW_NUMBER() OVER (PARTITION BY survey_id, question_id, key ORDER BY _weld_synced DESC) = 1
