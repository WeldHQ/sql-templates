-- core_typeform__answer_detail
-- Every answer to every question, in long format, with choice answers unnested.
-- Grain: typeform_account x response x question x selected choice. A non-choice
-- answer is one row with NULL choice columns; a multi-select answer is one row per
-- option ticked.
-- Depends on: staging.typeform.response, .response_answer, .response_answer_choice,
--             .form_field, .form
--
-- This is the model for answer distributions: count rows per `answer_value` for a
-- question and you have Typeform's per-question summary. For a multi-select
-- question the counts add up to more than the number of respondents, by design;
-- divide by `COUNT(DISTINCT response_token)` for "share of respondents who
-- picked this option", which is what Typeform's Results page shows.

SELECT
    a.typeform_account,
    a.form_id,
    f.form_title,
    a.response_token,
    r.submitted_at,
    DATE(r.submitted_at) AS submitted_date,

    a.field_id,
    -- Falls back to the answer's own ref when the question has since been deleted
    -- from the form and has no row in form_field any more.
    COALESCE(q.field_title, a.field_ref) AS question,
    COALESCE(q.field_type, a.field_type) AS field_type,
    q.parent_field_id,
    a.answer_type,

    c.choice_id,
    c.choice_text,
    -- One display value per row, whatever the answer type, for grouping in BI.
    COALESCE(
        c.choice_text,
        a.answer_text,
        a.answer_email,
        a.answer_phone_number,
        a.answer_file_url,
        CAST(a.answer_number AS STRING),
        CAST(a.answer_boolean AS STRING),
        CAST(a.answer_date AS STRING)
    ) AS answer_value,
    a.answer_number,
    a.answer_boolean,
    a.answer_date
FROM {{ ref('stg_typeform__response_answer') }} a
-- INNER: an answer whose response row is missing cannot be dated, and would be a
-- partially loaded sync rather than real data.
INNER JOIN {{ ref('stg_typeform__response') }} r
        ON r.typeform_account = a.typeform_account
       AND r.form_id          = a.form_id
       AND r.response_token   = a.response_token
-- LEFT, because only choice answers have choice rows. The join is on the full
-- answer key, so it fans out one answer into its selected choices and nothing else.
LEFT JOIN {{ ref('stg_typeform__response_answer_choice') }} c
       ON c.typeform_account = a.typeform_account
      AND c.form_id          = a.form_id
      AND c.response_token   = a.response_token
      AND c.field_id         = a.field_id
LEFT JOIN {{ ref('stg_typeform__form_field') }} q
       ON q.typeform_account = a.typeform_account
      AND q.form_id          = a.form_id
      AND q.field_id         = a.field_id
LEFT JOIN {{ ref('stg_typeform__form') }} f
       ON f.typeform_account = a.typeform_account
      AND f.form_id          = a.form_id
