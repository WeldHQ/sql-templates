-- staging.typeform.response_answer
-- Thin wrapper over raw `response_answer`. One row per response x answered question.
-- Questions the respondent skipped have no row.
--
-- Typeform returns one value column per answer type, so exactly one of the value
-- columns is set on each row, matching `answer_type`. Choice answers carry no value
-- here: the selected choices are in `response_answer_choice`.
--
-- NOT SYNCED: the `url` and `payment` answer types have no value column, so those
-- answers arrive with every value column NULL.

SELECT
    'account_1'                         AS typeform_account,
    CAST(form_id AS STRING)             AS form_id,
    CAST(response_token AS STRING)      AS response_token,
    CAST(field_id AS STRING)            AS field_id,
    CAST(field_ref AS STRING)           AS field_ref,
    CAST(field_type AS STRING)          AS field_type,
    -- The shape of the value: text, choice, choices, number, boolean, email, date,
    -- phone_number, file_url, url, payment, ...
    CAST(type AS STRING)                AS answer_type,
    CAST(text AS STRING)                AS answer_text,
    CAST(number AS FLOAT64)             AS answer_number,
    CAST(boolean AS BOOL)               AS answer_boolean,
    CAST(email AS STRING)               AS answer_email,
    CAST(date AS DATE)                  AS answer_date,
    CAST(phone_number AS STRING)        AS answer_phone_number,
    CAST(file_url AS STRING)            AS answer_file_url
FROM {{raw.typeform.response_answer}}
QUALIFY ROW_NUMBER() OVER (PARTITION BY form_id, response_token, field_id ORDER BY _weld_synced DESC) = 1
