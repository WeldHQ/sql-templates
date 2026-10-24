-- stg_gong__scorecard_question
-- Thin wrapper over raw `scorecard_question`: the questions on each scorecard
-- template, with the scale range (min_range to max_range) a score is given on.
-- Used in core to put scores from differently scaled questions on 0 to 1.
--
-- Keyed on question_revision_id as well as question_id, because editing a
-- question's scale creates a new revision and old answers keep the old one.
--
-- Single Gong instance; see staging.gong.call.

SELECT
    'account_1'                                AS gong_account,
    CAST(scorecard_id AS STRING)               AS scorecard_id,
    CAST(question_id AS STRING)                AS question_id,
    CAST(question_revision_id AS STRING)       AS question_revision_id,
    NULLIF(CAST(question_text AS STRING), '')  AS question_text,
    NULLIF(CAST(question_type AS STRING), '')  AS question_type,
    CAST(min_range AS INT64)                   AS min_range,
    CAST(max_range AS INT64)                   AS max_range
FROM {{ source('gong', 'scorecard_question') }}
WHERE question_id IS NOT NULL
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY scorecard_id, question_id, question_revision_id ORDER BY _weld_synced DESC
) = 1
