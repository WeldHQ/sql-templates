-- core_zigpoll__score_summary
-- Average score per rating question per month, with NPS where the scale is 0 to 10.
-- Grain: month x zigpoll_account x poll x slide. Months are UTC calendar months of
-- the response's `created_at`. Only range and star-rating slides, synthetic polls
-- excluded.
-- Depends on: core.zigpoll.answer_detail, staging.zigpoll.slide_answer
--
-- Zigpoll has no NPS question type: an NPS question is a range slide whose options
-- are 0 to 10. The model reads each slide's options and classifies it as NPS only
-- when they are exactly the eleven whole numbers 0 to 10. Any other scale gets an
-- average and no NPS, because promoter and detractor cut-offs only mean something
-- on the 0 to 10 scale.
--
-- NPS = share of promoters (9 to 10) minus share of detractors (0 to 6), times 100,
-- computed from counts. Roll longer periods up by summing the counts and
-- recomputing, never by averaging monthly NPS values.

WITH slide_scales AS (
    SELECT
        zigpoll_account,
        slide_id,
        COUNT(*)                                    AS options,
        COUNTIF(SAFE_CAST(answer_title AS INT64) IS NOT NULL) AS numeric_options,
        MIN(SAFE_CAST(answer_title AS INT64))       AS scale_min,
        MAX(SAFE_CAST(answer_title AS INT64))       AS scale_max
    FROM {{ ref('stg_zigpoll__slide_answer') }}
    GROUP BY 1, 2
),

scored AS (
    SELECT
        d.zigpoll_account,
        d.poll_id,
        d.poll_title,
        d.slide_id,
        d.slide_title,
        d.slide_type,
        DATE_TRUNC(d.response_date, MONTH) AS month,
        -- The selected option's title is the number on the scale; the display
        -- string is the fallback when no option row was synced.
        COALESCE(SAFE_CAST(d.answer_title AS FLOAT64), SAFE_CAST(d.response_text AS FLOAT64)) AS score,
        COALESCE(sc.options = 11 AND sc.numeric_options = 11
                 AND sc.scale_min = 0 AND sc.scale_max = 10, FALSE) AS is_nps_scale,
        sc.scale_max
    FROM {{ ref('core_zigpoll__answer_detail') }} d
    LEFT JOIN slide_scales sc
           ON sc.zigpoll_account = d.zigpoll_account
          AND sc.slide_id        = d.slide_id
    WHERE d.slide_type IN ('range', 'star-rating')
      AND NOT COALESCE(d.is_synthetic, FALSE)
)

SELECT
    month,
    zigpoll_account,
    poll_id,
    poll_title,
    slide_id,
    slide_title,
    slide_type,
    is_nps_scale,
    scale_max,
    COUNTIF(score IS NOT NULL)  AS answers,
    SUM(score)                  AS total_score,
    AVG(score)                  AS avg_score,
    COUNTIF(is_nps_scale AND score >= 9)            AS promoters,
    COUNTIF(is_nps_scale AND score BETWEEN 7 AND 8) AS passives,
    COUNTIF(is_nps_scale AND score <= 6)            AS detractors,
    CASE WHEN is_nps_scale THEN
        100 * SAFE_DIVIDE(COUNTIF(score >= 9) - COUNTIF(score <= 6), COUNTIF(score IS NOT NULL))
    END AS nps,
    -- Answers whose value could not be read as a number; should be zero.
    COUNTIF(score IS NULL)      AS unscored_answers
FROM scored
GROUP BY month, zigpoll_account, poll_id, poll_title, slide_id, slide_title,
         slide_type, is_nps_scale, scale_max
