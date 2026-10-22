-- core.medallia.answer_detail
-- Every answer on every feedback record, in long format, with the question name,
-- option label and numeric score resolved.
-- Grain: medallia_account x feedback record x question x position. A
-- single-valued answer is one row; a multi-valued one is one row per value.
-- Depends on: staging.medallia.feedback_answer, .feedback, .field_meta_data,
--             .field_option, .unit
--
-- `score` is the option's numeric value for a fixed-option question (the number
-- behind "9 - Very likely"), or the answer itself when it is a plain number.
-- Comments and other text answers have a NULL score and their text in
-- `answer_label`.

SELECT
    a.medallia_account,
    a.feedback_id,
    f.status,
    f.survey_source,
    f.survey_method,
    f.responded_at,
    DATE(f.responded_at) AS responded_date,
    f.unit_identifier,
    u.unit_name,

    a.question_id,
    m.field_name AS question_name,
    m.data_type,
    a.position,
    a.answer_rank,
    a.answer_value,
    -- The option label when the answer is an option id, otherwise the value as
    -- given.
    COALESCE(o.option_name, a.answer_value) AS answer_label,
    COALESCE(CAST(o.numeric_value AS FLOAT64), SAFE_CAST(a.answer_value AS FLOAT64)) AS score
FROM {{staging.medallia.feedback_answer}} a
-- INNER: an answer whose record is missing cannot be dated or placed in a unit.
INNER JOIN {{staging.medallia.feedback}} f
        ON f.medallia_account = a.medallia_account
       AND f.feedback_id      = a.feedback_id
LEFT JOIN {{staging.medallia.field_meta_data}} m
       ON m.medallia_account = a.medallia_account
      AND m.field_id         = a.question_id
-- Option ids are unique within a field, so the join is on both.
LEFT JOIN {{staging.medallia.field_option}} o
       ON o.medallia_account = a.medallia_account
      AND o.field_id         = a.question_id
      AND o.option_id        = a.answer_value
LEFT JOIN {{staging.medallia.unit}} u
       ON u.medallia_account = f.medallia_account
      AND u.unit_identifier  = f.unit_identifier
