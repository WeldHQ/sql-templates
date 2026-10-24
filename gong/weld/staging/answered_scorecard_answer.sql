-- staging.gong.answered_scorecard_answer
-- Thin wrapper over raw `answered_scorecard_answer`: one row per question answered
-- on a filled-in scorecard.
--
-- `score` is set for scale questions and NULL for free-text and yes/no ones.
-- `is_overall` marks the scorecard's overall-score question. not_applicable answers
-- are kept here and excluded in core.
--
-- Single Gong instance; see staging.gong.call.

SELECT
    'account_1'                                AS gong_account,
    CAST(answered_scorecard_id AS STRING)      AS answered_scorecard_id,
    CAST(question_id AS STRING)                AS question_id,
    CAST(question_revision_id AS STRING)       AS question_revision_id,
    CAST(score AS INT64)                       AS score,
    COALESCE(CAST(is_overall AS BOOL), FALSE)  AS is_overall,
    COALESCE(CAST(not_applicable AS BOOL), FALSE) AS is_not_applicable
FROM {{raw.gong.answered_scorecard_answer}}
WHERE answered_scorecard_id IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY answered_scorecard_id, question_id ORDER BY _weld_synced DESC) = 1
