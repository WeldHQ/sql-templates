-- core.qualtrics.answer_detail
-- Every answer to every question, in long format, with question and matrix-row
-- text attached.
-- Grain: qualtrics_account x response x question x sub question x response_index.
-- A single-answer question is one row; a multi-select answer is one row per choice
-- selected; a matrix answer is one row per matrix row (sub question).
-- Depends on: staging.qualtrics.question_response, .survey_response, .question,
--             .sub_question, .survey
--
-- Test, preview and spam responses are kept but flagged with `is_test_or_spam`;
-- filter on it for anything that should match Qualtrics' reports.
--
-- For an answer distribution, count rows per `response_label` for one question
-- (and one `sub_question_key` on a matrix). For a multi-select question the counts
-- add up to more than the number of respondents; divide by
-- COUNT(DISTINCT response_id) for the share of respondents choosing each option.

SELECT
    a.qualtrics_account,
    r.survey_id,
    s.survey_name,
    a.response_id,
    r.recorded_at,
    DATE(r.recorded_at) AS recorded_date,
    r.is_finished,
    r.is_test_or_spam,
    r.distribution_channel,

    a.question_id,
    q.question_name,
    q.question_text,
    q.question_type,
    q.selector,
    a.sub_question_key,
    sq.sub_question_text,
    a.response_index,

    -- The exported value (a choice's recode, or the typed text) and the label the
    -- respondent saw. Use the label for display and the value for arithmetic.
    a.response_value,
    a.response_label,
    SAFE_CAST(a.response_value AS FLOAT64) AS response_number
FROM {{staging.qualtrics.question_response}} a
-- INNER: the response row carries the survey id, without which a question id
-- (QID1) cannot be resolved, because question ids repeat across surveys.
INNER JOIN {{staging.qualtrics.survey_response}} r
        ON r.qualtrics_account = a.qualtrics_account
       AND r.response_id       = a.response_id
LEFT JOIN {{staging.qualtrics.question}} q
       ON q.qualtrics_account = a.qualtrics_account
      AND q.survey_id         = r.survey_id
      AND q.question_id       = a.question_id
LEFT JOIN {{staging.qualtrics.sub_question}} sq
       ON sq.qualtrics_account = a.qualtrics_account
      AND sq.survey_id         = r.survey_id
      AND sq.question_id       = a.question_id
      AND sq.sub_question_key  = a.sub_question_key
LEFT JOIN {{staging.qualtrics.survey}} s
       ON s.qualtrics_account = a.qualtrics_account
      AND s.survey_id         = r.survey_id
