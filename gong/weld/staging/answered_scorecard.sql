-- staging.gong.answered_scorecard
-- Thin wrapper over raw `answered_scorecard`: one row per scorecard a reviewer
-- filled in for a call. `reviewed_user_id` is the rep being scored,
-- `reviewer_user_id` the person scoring.
--
-- Single Gong instance; see staging.gong.call.

SELECT
    'account_1'                                AS gong_account,
    CAST(answered_scorecard_id AS STRING)      AS answered_scorecard_id,
    CAST(scorecard_id AS STRING)               AS scorecard_id,
    NULLIF(CAST(scorecard_name AS STRING), '') AS scorecard_name,
    CAST(call_id AS STRING)                    AS call_id,
    CAST(call_start_time AS TIMESTAMP)         AS call_started_at,
    CAST(review_time AS TIMESTAMP)             AS reviewed_at,
    CAST(reviewed_user_id AS STRING)           AS reviewed_user_id,
    CAST(reviewer_user_id AS STRING)           AS reviewer_user_id,
    NULLIF(CAST(visibility_type AS STRING), '') AS visibility_type
FROM {{raw.gong.answered_scorecard}}
WHERE answered_scorecard_id IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY answered_scorecard_id ORDER BY _weld_synced DESC) = 1
