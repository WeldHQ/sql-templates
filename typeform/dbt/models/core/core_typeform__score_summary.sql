-- core_typeform__score_summary
-- NPS, average score and top-two-box (CSAT-style) per scale question per month.
-- Grain: month x typeform_account x form x question. Months are UTC calendar
-- months of `submitted_at`. Only questions of type nps, opinion_scale and rating.
-- Depends on: staging.typeform.response_answer, .response, .form_field,
--             .form_field_property, .form
--
-- NPS is computed from counts: share of promoters (9 to 10) minus share of
-- detractors (0 to 6), times 100. The counts are returned too, so a quarter or a
-- year is rolled up by summing the counts and recomputing, never by averaging the
-- monthly NPS values. Averaging monthly NPS weights a month with five answers the
-- same as a month with five hundred.
--
-- NPS is only returned for Typeform's dedicated NPS question type, which is always
-- 0 to 10. An opinion scale someone set up as 0 to 10 is not treated as NPS: use
-- Typeform's NPS question if you want the classification.
--
-- TOP TWO BOX: share of answers in the top two points of the scale, the usual
-- CSAT definition (4 or 5 on a five-point scale). The top of the scale is read
-- from the question's own settings: `steps` for a rating, and `steps` plus
-- `start_at_one` for an opinion scale (which runs 0 to steps-1, or 1 to steps).
-- When the setting is missing the rate is NULL rather than guessed.

WITH scale_fields AS (
    SELECT
        q.typeform_account,
        q.form_id,
        q.field_id,
        q.field_title,
        q.field_type,
        SAFE_CAST(MAX(IF(p.property_key = 'steps', p.property_value, NULL)) AS INT64) AS steps,
        LOGICAL_OR(p.property_key = 'start_at_one' AND LOWER(p.property_value) = 'true') AS starts_at_one
    FROM {{ ref('stg_typeform__form_field') }} q
    LEFT JOIN {{ ref('stg_typeform__form_field_property') }} p
           ON p.typeform_account = q.typeform_account
          AND p.form_id          = q.form_id
          AND p.field_id         = q.field_id
    WHERE q.field_type IN ('nps', 'opinion_scale', 'rating')
    GROUP BY 1, 2, 3, 4, 5
),

scale_fields_with_max AS (
    SELECT
        *,
        CASE
            WHEN field_type = 'nps'           THEN 10
            WHEN field_type = 'rating'        THEN steps
            WHEN field_type = 'opinion_scale' THEN steps - 1 + IF(COALESCE(starts_at_one, FALSE), 1, 0)
        END AS scale_max
    FROM scale_fields
),

scores AS (
    SELECT
        a.typeform_account,
        a.form_id,
        a.field_id,
        DATE_TRUNC(DATE(r.submitted_at), MONTH) AS month,
        a.answer_number AS score
    FROM {{ ref('stg_typeform__response_answer') }} a
    INNER JOIN {{ ref('stg_typeform__response') }} r
            ON r.typeform_account = a.typeform_account
           AND r.form_id          = a.form_id
           AND r.response_token   = a.response_token
    WHERE a.answer_number IS NOT NULL
)

SELECT
    s.month,
    s.typeform_account,
    s.form_id,
    fm.form_title,
    s.field_id,
    f.field_title AS question,
    f.field_type,
    f.scale_max,

    COUNT(*)     AS answers,
    SUM(s.score) AS total_score,
    AVG(s.score) AS avg_score,

    -- NPS buckets, Typeform NPS questions only.
    COUNTIF(f.field_type = 'nps' AND s.score >= 9)                AS promoters,
    COUNTIF(f.field_type = 'nps' AND s.score BETWEEN 7 AND 8)     AS passives,
    COUNTIF(f.field_type = 'nps' AND s.score <= 6)                AS detractors,
    CASE WHEN f.field_type = 'nps' THEN
        100 * SAFE_DIVIDE(COUNTIF(s.score >= 9) - COUNTIF(s.score <= 6), COUNT(*))
    END AS nps,

    -- Top two box. NULL when the scale's top could not be read from the settings.
    CASE WHEN f.scale_max IS NOT NULL THEN COUNTIF(s.score >= f.scale_max - 1) END AS top_two_box_answers,
    CASE WHEN f.scale_max IS NOT NULL THEN SAFE_DIVIDE(COUNTIF(s.score >= f.scale_max - 1), COUNT(*)) END
        AS top_two_box_rate
FROM scores s
-- INNER: this is what restricts the model to scale questions.
INNER JOIN scale_fields_with_max f
        ON f.typeform_account = s.typeform_account
       AND f.form_id          = s.form_id
       AND f.field_id         = s.field_id
LEFT JOIN {{ ref('stg_typeform__form') }} fm
       ON fm.typeform_account = s.typeform_account
      AND fm.form_id          = s.form_id
GROUP BY s.month, s.typeform_account, s.form_id, fm.form_title, s.field_id,
         f.field_title, f.field_type, f.scale_max
