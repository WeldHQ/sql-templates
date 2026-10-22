-- stg_qualtrics__question
-- Thin wrapper over raw `question`. One row per question per survey, as the survey
-- is defined now.
--
-- Question ids (QID1, QID2, ...) are only unique within a survey, so survey_id is
-- part of the key and of every join on this model.
--
-- `question_type` and `selector` together say what kind of question it is: an NPS
-- question is type MC with selector NPS; a matrix is type Matrix; a text entry is
-- type TE.

SELECT
    'account_1'                                    AS qualtrics_account,
    CAST(survey_id AS STRING)                      AS survey_id,
    CAST(id AS STRING)                             AS question_id,
    CAST(question_name AS STRING)                  AS question_name,
    NULLIF(TRIM(CAST(question_text AS STRING)), '') AS question_text,
    CAST(question_label AS STRING)                 AS question_label,
    CAST(type AS STRING)                           AS question_type,
    CAST(type_selector AS STRING)                  AS selector,
    CAST(type_sub_selector AS STRING)              AS sub_selector,
    CAST(validation_force_response AS BOOL)        AS is_forced_response
FROM {{ source('qualtrics', 'question') }}
QUALIFY ROW_NUMBER() OVER (PARTITION BY survey_id, id ORDER BY _weld_synced DESC) = 1
