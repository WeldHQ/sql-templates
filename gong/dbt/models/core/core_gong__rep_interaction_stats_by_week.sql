-- core_gong__rep_interaction_stats_by_week
-- Gong's Interaction stats per rep per week: talk ratio, longest monologue,
-- longest customer story, interactivity, patience and question rate.
--
-- Grain: ISO week (starting Monday) x gong_account x rep (primary user).
-- Depends on: core.gong.calls
--
-- EXTERNAL CALLS ONLY. Interaction stats are a coaching measure for conversations
-- with customers and prospects; an internal stand-up would drag every rep's talk
-- ratio toward 50%. Remove the scope filter to include them.
--
-- AVERAGE OF PER-CALL VALUES, ON PURPOSE. Gong's help centre defines a rep's
-- average talk ratio as the sum of their per-call talk ratios divided by the number
-- of calls, so a 10-minute call weighs the same as a 60-minute one. The avg_gong_*
-- columns follow that definition so they can be checked against the Gong UI.
-- talk_time_weighted_rep_talk_ratio is the other reading (total rep seconds over
-- total seconds), which long calls dominate. They disagree whenever call lengths
-- vary; neither is a bug.
--
-- To re-aggregate to month or team, sum the *_sum and *_calls columns and divide.
-- Averaging the avg_ columns gives a mean of means.
--
-- No spine: a week with no external calls has no stats to average, and a zero
-- would be read as a talk ratio of 0%.

SELECT
    DATE_TRUNC(call_date, ISOWEEK)                                AS week_start,
    gong_account,
    primary_user_id                                               AS user_id,
    ANY_VALUE(rep_name)                                           AS user_name,
    ANY_VALUE(rep_manager_name)                                   AS manager_name,

    COUNT(*)                                                      AS external_calls,
    SUM(duration_minutes)                                         AS external_call_minutes,

    -- Gong's own statistics, averaged per call.
    COUNT(gong_talk_ratio)                                        AS gong_talk_ratio_calls,
    SUM(gong_talk_ratio)                                          AS gong_talk_ratio_sum,
    AVG(gong_talk_ratio)                                          AS avg_gong_talk_ratio,
    AVG(gong_longest_monologue)                                   AS avg_gong_longest_monologue,
    AVG(gong_longest_customer_story)                              AS avg_gong_longest_customer_story,
    AVG(gong_interactivity)                                       AS avg_gong_interactivity,
    AVG(gong_patience)                                            AS avg_gong_patience,
    AVG(gong_question_rate)                                       AS avg_gong_question_rate,

    -- The same idea computed from speaker talk time.
    COUNT(rep_talk_ratio)                                         AS rep_talk_ratio_calls,
    SUM(rep_talk_ratio)                                           AS rep_talk_ratio_sum,
    AVG(rep_talk_ratio)                                           AS avg_rep_talk_ratio,
    SUM(rep_talk_seconds)                                         AS rep_talk_seconds,
    SUM(total_talk_seconds)                                       AS total_talk_seconds,
    SAFE_DIVIDE(SUM(rep_talk_seconds), SUM(total_talk_seconds))   AS talk_time_weighted_rep_talk_ratio,

    SUM(questions_asked_by_company)                               AS questions_asked_by_company,
    SUM(questions_asked_by_others)                                AS questions_asked_by_others
FROM {{ ref('core_gong__calls') }}
WHERE scope = 'External'
  AND call_date IS NOT NULL
  AND primary_user_id IS NOT NULL
GROUP BY 1, 2, 3
