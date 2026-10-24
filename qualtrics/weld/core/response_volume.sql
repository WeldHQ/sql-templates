-- core.qualtrics.response_volume
-- Recorded responses per survey per day, finished and unfinished, with duration.
-- Grain: day x qualtrics_account x survey. Dates are UTC days of `recorded_at`,
-- the timestamp Qualtrics' own response counts use.
-- Depends on: staging.qualtrics.survey_response, .survey
--
-- Previews, test responses, synthetic responses and spam are excluded from every
-- count and returned separately in `excluded_test_or_spam`, so the exclusion is
-- visible rather than silent. If your Data & Analysis view includes previews,
-- add that column back before comparing.
--
-- Built on a day spine so a quiet day returns zeros instead of disappearing.
--
-- CHANNEL. Responses are also split by how the respondent arrived, from
-- Qualtrics' distribution_channel: `email` (an email invite), `smsinvite` (an
-- SMS invite), `anonymous` (the anonymous survey link) and `gl` (a personal
-- link). Everything else (QR codes, social, offline app, imports) lands in
-- responses_other_channel, so the five columns always add up to `responses`.
--
-- HOW FAR ABANDONERS GOT. Qualtrics records `progress` (0 to 100) on every
-- response. For unfinished responses its mean says whether people drop out on
-- the first page or near the end; the sum and count are returned so it can be
-- rolled up as a ratio of sums.
--
-- FINISH RATE: `finished / responses` is the share of RECORDED responses that were
-- finished. Responses still in progress are not exported, so this is not the share
-- of people who started; for that, use distribution_performance (email invites
-- only) or Qualtrics' own survey stats.

WITH responses AS (
    SELECT
        qualtrics_account,
        survey_id,
        DATE(recorded_at) AS recorded_date,
        is_test_or_spam,
        is_finished,
        duration_seconds,
        progress_pct,
        LOWER(distribution_channel) AS channel
    FROM {{staging.qualtrics.survey_response}}
    WHERE recorded_at IS NOT NULL
),

day_spine AS (
    SELECT day
    FROM UNNEST(GENERATE_DATE_ARRAY(
        (SELECT MIN(recorded_date) FROM responses),
        CURRENT_DATE(),
        INTERVAL 1 DAY
    )) AS day
),

surveys AS (
    -- Only surveys that have recorded at least one response.
    SELECT DISTINCT r.qualtrics_account, r.survey_id, s.survey_name
    FROM responses r
    LEFT JOIN {{staging.qualtrics.survey}} s
           ON s.qualtrics_account = r.qualtrics_account
          AND s.survey_id         = r.survey_id
),

daily AS (
    SELECT
        recorded_date AS day,
        qualtrics_account,
        survey_id,
        COUNTIF(NOT is_test_or_spam)                         AS responses,
        COUNTIF(NOT is_test_or_spam AND is_finished)         AS finished,
        COUNTIF(NOT is_test_or_spam AND NOT is_finished)     AS unfinished,
        -- Duration over finished responses only: an abandoned response's duration
        -- is how long it sat open before Qualtrics closed it, not time to complete.
        SUM(IF(NOT is_test_or_spam AND is_finished, duration_seconds, NULL))   AS total_duration_seconds,
        COUNTIF(NOT is_test_or_spam AND is_finished AND duration_seconds IS NOT NULL) AS finished_with_duration,
        SUM(IF(NOT is_test_or_spam AND NOT is_finished, progress_pct, NULL))   AS unfinished_progress_pct_total,
        COUNTIF(NOT is_test_or_spam AND NOT is_finished AND progress_pct IS NOT NULL) AS unfinished_with_progress,
        COUNTIF(NOT is_test_or_spam AND channel = 'email')     AS responses_email,
        COUNTIF(NOT is_test_or_spam AND channel = 'smsinvite') AS responses_sms,
        COUNTIF(NOT is_test_or_spam AND channel = 'anonymous') AS responses_anonymous_link,
        COUNTIF(NOT is_test_or_spam AND channel = 'gl')        AS responses_personal_link,
        COUNTIF(NOT is_test_or_spam
                AND COALESCE(channel, '') NOT IN ('email', 'smsinvite', 'anonymous', 'gl')) AS responses_other_channel,
        COUNTIF(is_test_or_spam)                             AS excluded_test_or_spam
    FROM responses
    GROUP BY 1, 2, 3
)

SELECT
    s.day,
    v.qualtrics_account,
    v.survey_id,
    v.survey_name,
    COALESCE(d.responses, 0)              AS responses,
    COALESCE(d.finished, 0)               AS finished,
    COALESCE(d.unfinished, 0)             AS unfinished,
    SAFE_DIVIDE(d.finished, d.responses)  AS finish_rate,
    -- Sum and count are returned so a longer period recomputes the mean as a ratio
    -- of sums instead of averaging daily averages.
    COALESCE(d.total_duration_seconds, 0) AS total_duration_seconds,
    COALESCE(d.finished_with_duration, 0) AS finished_with_duration,
    SAFE_DIVIDE(d.total_duration_seconds, d.finished_with_duration) AS avg_duration_seconds,
    COALESCE(d.unfinished_progress_pct_total, 0) AS unfinished_progress_pct_total,
    COALESCE(d.unfinished_with_progress, 0)      AS unfinished_with_progress,
    SAFE_DIVIDE(d.unfinished_progress_pct_total, d.unfinished_with_progress) AS avg_unfinished_progress_pct,
    COALESCE(d.responses_email, 0)          AS responses_email,
    COALESCE(d.responses_sms, 0)            AS responses_sms,
    COALESCE(d.responses_anonymous_link, 0) AS responses_anonymous_link,
    COALESCE(d.responses_personal_link, 0)  AS responses_personal_link,
    COALESCE(d.responses_other_channel, 0)  AS responses_other_channel,
    COALESCE(d.excluded_test_or_spam, 0)  AS excluded_test_or_spam
FROM day_spine s
CROSS JOIN surveys v
LEFT JOIN daily d
       ON d.day               = s.day
      AND d.qualtrics_account = v.qualtrics_account
      AND d.survey_id         = v.survey_id
