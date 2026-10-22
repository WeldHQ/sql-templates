-- core_typeform__response_volume
-- Submitted responses per form per day, with time to complete.
-- Grain: day x typeform_account x form. Dates are UTC days of `submitted_at`.
-- Depends on: staging.typeform.response, .form
--
-- Built on a day spine so a form with a quiet day still returns a row of zeros
-- instead of vanishing from the series, which would let a BI line chart draw
-- straight over the gap.
--
-- WHAT THIS IS NOT: a completion rate. The connector syncs submitted responses
-- only, with no views, starts or partial responses, so there is no denominator.
-- Typeform's Results page shows those figures; this model reconciles to its
-- "Responses" count.

WITH responses AS (
    SELECT
        typeform_account,
        form_id,
        response_token,
        DATE(submitted_at) AS submitted_date,
        calculated_score,
        -- Time from opening the form to submitting it. A respondent who leaves the
        -- tab open overnight produces a huge value, so the median is returned
        -- alongside the mean.
        TIMESTAMP_DIFF(submitted_at, landed_at, SECOND) AS seconds_to_complete
    FROM {{ ref('stg_typeform__response') }}
    WHERE submitted_at IS NOT NULL
),

day_spine AS (
    SELECT day
    FROM UNNEST(GENERATE_DATE_ARRAY(
        (SELECT MIN(submitted_date) FROM responses),
        CURRENT_DATE(),
        INTERVAL 1 DAY
    )) AS day
),

forms AS (
    -- Only forms that have ever received a response, so drafts and abandoned
    -- forms do not pad the series with years of zeros.
    SELECT DISTINCT r.typeform_account, r.form_id, f.form_title
    FROM responses r
    LEFT JOIN {{ ref('stg_typeform__form') }} f
           ON f.typeform_account = r.typeform_account
          AND f.form_id          = r.form_id
),

daily AS (
    SELECT
        submitted_date AS day,
        typeform_account,
        form_id,
        COUNT(*)                                       AS responses,
        SUM(seconds_to_complete)                       AS total_seconds_to_complete,
        COUNT(seconds_to_complete)                     AS responses_with_duration,
        APPROX_QUANTILES(seconds_to_complete, 2)[OFFSET(1)] AS median_seconds_to_complete,
        SUM(calculated_score)                          AS total_calculated_score,
        COUNT(calculated_score)                        AS responses_with_score
    FROM responses
    GROUP BY 1, 2, 3
)

SELECT
    s.day,
    f.typeform_account,
    f.form_id,
    f.form_title,
    COALESCE(d.responses, 0) AS responses,
    -- Sums and counts are returned so a weekly or monthly roll-up can recompute the
    -- mean as a ratio of sums. Averaging the daily averages would weight a day
    -- with one response the same as a day with a thousand.
    COALESCE(d.total_seconds_to_complete, 0) AS total_seconds_to_complete,
    COALESCE(d.responses_with_duration, 0)   AS responses_with_duration,
    SAFE_DIVIDE(d.total_seconds_to_complete, d.responses_with_duration) AS avg_seconds_to_complete,
    -- Median for this day only; it cannot be rolled up.
    d.median_seconds_to_complete,
    COALESCE(d.total_calculated_score, 0)    AS total_calculated_score,
    COALESCE(d.responses_with_score, 0)      AS responses_with_score,
    SAFE_DIVIDE(d.total_calculated_score, d.responses_with_score) AS avg_calculated_score
FROM day_spine s
CROSS JOIN forms f
LEFT JOIN daily d
       ON d.day              = s.day
      AND d.typeform_account = f.typeform_account
      AND d.form_id          = f.form_id
