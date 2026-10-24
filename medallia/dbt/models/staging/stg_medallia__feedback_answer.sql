-- stg_medallia__feedback_answer
-- Thin wrapper over raw `feedback_answer`. One row per feedback record x question x
-- value. Every question field (q_*) and every multi-valued field lands here rather
-- than as a column of feedback, because an instance can have thousands of them.
--
-- `value` is the option id for a question with fixed options (rating scales,
-- multiple choice); look it up in field_option for the label and the numeric value.
-- For free text and plain numbers it is the value itself. `position` numbers the
-- values of a multi-valued answer; `answer_rank` is set on ranking questions.
--
-- When a record is updated and a multi-valued answer shrinks, the rows past its new
-- last position stay until the table is fully re-synced.

SELECT
    'account_1'                       AS medallia_account,
    CAST(feedback_id AS STRING)       AS feedback_id,
    CAST(question_id AS STRING)       AS question_id,
    CAST(position AS INT64)           AS position,
    CAST(value AS STRING)             AS answer_value,
    CAST(rank AS INT64)               AS answer_rank
FROM {{ source('medallia', 'feedback_answer') }}
QUALIFY ROW_NUMBER() OVER (PARTITION BY feedback_id, question_id, position ORDER BY _weld_synced DESC) = 1
