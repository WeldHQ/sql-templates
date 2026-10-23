-- staging.qualtrics.survey_response
-- Thin wrapper over raw `survey_response`. One row per recorded response.
--
-- Only recorded responses are synced: completed ones, and incomplete ones
-- Qualtrics has closed and recorded. Responses still in progress are not synced, so `finished = FALSE` here means "recorded
-- as incomplete", not "currently being filled in".
--
-- `status` is Qualtrics' response type code. It is decoded here and flagged, so
-- core can drop previews, test responses, synthetic responses and spam.

SELECT
    'account_1'                              AS qualtrics_account,
    CAST(survey_id AS STRING)                AS survey_id,
    CAST(response_id AS STRING)              AS response_id,
    CAST(start_date AS TIMESTAMP)            AS started_at,
    CAST(end_date AS TIMESTAMP)              AS ended_at,
    CAST(recorded_date AS TIMESTAMP)         AS recorded_at,
    CAST(last_modified_date AS TIMESTAMP)    AS last_modified_at,
    CAST(status AS INT64)                    AS status_code,
    CASE CAST(status AS INT64)
        WHEN 0   THEN 'IP Address'
        WHEN 1   THEN 'Survey Preview'
        WHEN 2   THEN 'Survey Test'
        WHEN 4   THEN 'Imported'
        WHEN 16  THEN 'Offline'
        WHEN 17  THEN 'Offline Preview'
        WHEN 256 THEN 'Synthetic'
        -- 6, 8 and 12 are spam statuses Qualtrics has since deprecated; older
        -- surveys can still carry them.
        WHEN 6   THEN 'Spam'
        WHEN 8   THEN 'Spam'
        WHEN 12  THEN 'Spam'
    END                                      AS response_type,
    -- Previews, tests, synthetic panel responses and legacy spam statuses.
    CAST(status AS INT64) IN (1, 2, 6, 8, 12, 17, 256) AS is_test_or_spam,
    CAST(finished AS INT64) = 1              AS is_finished,
    -- Percentage of the survey the respondent got through, 0 to 100.
    CAST(progress AS INT64)                  AS progress_pct,
    -- Seconds from start to end, as Qualtrics measures it.
    CAST(duration AS INT64)                  AS duration_seconds,
    -- anonymous, email, sms, preview, test, ...
    CAST(distribution_channel AS STRING)     AS distribution_channel,
    CAST(user_language AS STRING)            AS user_language,
    CAST(recipient_email AS STRING)          AS recipient_email
FROM {{raw.qualtrics.survey_response}}
QUALIFY ROW_NUMBER() OVER (PARTITION BY survey_id, response_id ORDER BY _weld_synced DESC) = 1
