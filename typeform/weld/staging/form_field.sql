-- staging.typeform.form_field
-- Thin wrapper over raw `form_field`. One row per question on a form, as the form
-- is defined now.
--
-- Questions inside a question group are synced as their own rows, with the group's
-- id in `parent_field_id`, so every answerable question has exactly one row here.
--
-- CURRENT DEFINITION ONLY: if a question is deleted from a form, old answers still
-- carry its field id but it may no longer have a row here. Core models therefore
-- LEFT JOIN this table and fall back to the answer's own `field_ref`.

SELECT
    'account_1'                              AS typeform_account,
    CAST(form_id AS STRING)                  AS form_id,
    CAST(id AS STRING)                       AS field_id,
    CAST(ref AS STRING)                      AS field_ref,
    NULLIF(TRIM(CAST(title AS STRING)), '')  AS field_title,
    -- Typeform's question type: nps, opinion_scale, rating, multiple_choice,
    -- dropdown, yes_no, short_text, long_text, email, date, group, ...
    CAST(type AS STRING)                     AS field_type,
    CAST(form_parent_field_id AS STRING)     AS parent_field_id,
    CAST(validations_required AS BOOL)       AS is_required
FROM {{raw.typeform.form_field}}
QUALIFY ROW_NUMBER() OVER (PARTITION BY form_id, id ORDER BY _weld_synced DESC) = 1
