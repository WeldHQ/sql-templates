-- core.gong.scorecard_scores_by_rep
-- Coaching scorecards per rep per month: how many calls were reviewed, by how many
-- reviewers, and the average scores the rep received.
--
-- Grain: review month x gong_account x reviewed rep x scorecard.
-- Depends on: staging.gong.answered_scorecard, .answered_scorecard_answer,
--             .scorecard_question, .user
--
-- SCORES ARE PUT ON 0 TO 1 before averaging. Gong scorecards let each scale
-- question have its own range (1 to 5, 1 to 10), so averaging raw scores across
-- questions or scorecards mixes scales. normalised = (score - min) / (max - min),
-- using the range of the question revision the answer was given on. Raw averages
-- are kept alongside for matching the Gong UI on a single scorecard.
--
-- not_applicable answers and answers without a numeric score (free text, yes/no,
-- multiple choice) are excluded from every average.
--
-- Months are by review date, not call date: coaching activity happens when the
-- manager reviews, which can be weeks after the call.

WITH answer AS (
    SELECT
        s.gong_account,
        s.answered_scorecard_id,
        s.scorecard_id,
        s.scorecard_name,
        s.reviewed_user_id,
        s.reviewer_user_id,
        s.reviewed_at,
        a.is_overall,
        a.score,
        SAFE_DIVIDE(a.score - q.min_range, q.max_range - q.min_range) AS normalised_score
    FROM {{staging.gong.answered_scorecard}} s
    JOIN {{staging.gong.answered_scorecard_answer}} a
        ON  a.gong_account          = s.gong_account
        AND a.answered_scorecard_id = s.answered_scorecard_id
    LEFT JOIN {{staging.gong.scorecard_question}} q
        ON  q.gong_account         = a.gong_account
        AND q.scorecard_id         = s.scorecard_id
        AND q.question_id          = a.question_id
        AND q.question_revision_id = a.question_revision_id
    WHERE NOT a.is_not_applicable
      AND a.score IS NOT NULL
),

scorecards AS (
    -- Counted from the header table, not from answers, so a scorecard with only
    -- free-text answers still counts as a review.
    SELECT
        gong_account,
        DATE_TRUNC(DATE(reviewed_at), MONTH)        AS review_month,
        reviewed_user_id,
        scorecard_id,
        ANY_VALUE(scorecard_name)                   AS scorecard_name,
        COUNT(*)                                    AS scorecards_answered,
        COUNT(DISTINCT call_id)                     AS calls_reviewed,
        COUNT(DISTINCT reviewer_user_id)            AS reviewers
    FROM {{staging.gong.answered_scorecard}}
    WHERE reviewed_at IS NOT NULL
    GROUP BY 1, 2, 3, 4
),

scores AS (
    SELECT
        gong_account,
        DATE_TRUNC(DATE(reviewed_at), MONTH)        AS review_month,
        reviewed_user_id,
        scorecard_id,
        AVG(IF(is_overall, score, NULL))            AS avg_overall_score,
        AVG(IF(is_overall, normalised_score, NULL)) AS avg_overall_score_normalised,
        AVG(IF(NOT is_overall, score, NULL))        AS avg_question_score,
        AVG(IF(NOT is_overall, normalised_score, NULL)) AS avg_question_score_normalised,
        COUNTIF(NOT is_overall)                     AS scored_answers
    FROM answer
    WHERE reviewed_at IS NOT NULL
    GROUP BY 1, 2, 3, 4
)

SELECT
    sc.review_month,
    sc.gong_account,
    sc.reviewed_user_id,
    u.user_name                                      AS reviewed_user_name,
    u.manager_id,
    m.user_name                                      AS manager_name,
    sc.scorecard_id,
    sc.scorecard_name,
    sc.scorecards_answered,
    sc.calls_reviewed,
    sc.reviewers,
    COALESCE(s.scored_answers, 0)                    AS scored_answers,
    s.avg_overall_score,
    s.avg_overall_score_normalised,
    s.avg_question_score,
    s.avg_question_score_normalised
FROM scorecards sc
LEFT JOIN scores s
    ON  s.gong_account      = sc.gong_account
    AND s.review_month      = sc.review_month
    AND s.reviewed_user_id  = sc.reviewed_user_id
    AND s.scorecard_id      = sc.scorecard_id
LEFT JOIN {{staging.gong.user}} u
    ON  u.gong_account = sc.gong_account AND u.user_id = sc.reviewed_user_id
LEFT JOIN {{staging.gong.user}} m
    ON  m.gong_account = u.gong_account AND m.user_id = u.manager_id
