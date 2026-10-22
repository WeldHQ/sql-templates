-- staging.typeform.form_field_property
-- Thin wrapper over raw `form_field_property`. One row per question setting, as
-- key/value pairs, because the available settings differ by question type
-- (`steps` and `start_at_one` on opinion scales, `allow_multiple_selection` on
-- multiple choice, and so on).
--
-- Every value arrives as a string; booleans are the strings 'true' and 'false'.
-- Pivoting the keys a report needs is left to core.

SELECT
    'account_1'                 AS typeform_account,
    CAST(form_id AS STRING)     AS form_id,
    CAST(field_id AS STRING)    AS field_id,
    CAST(key AS STRING)         AS property_key,
    CAST(value AS STRING)       AS property_value
FROM {{raw.typeform.form_field_property}}
QUALIFY ROW_NUMBER() OVER (PARTITION BY form_id, field_id, key ORDER BY _weld_synced DESC) = 1
