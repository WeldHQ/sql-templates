-- stg_typeform__form
-- Thin wrapper over raw `form`. One row per form (typeform).
--
-- A form is synced again whenever Typeform reports it as updated, and appears
-- once. A deleted form is not removed from the table;
-- it simply stops receiving updates.

SELECT
    'account_1'                              AS typeform_account,
    CAST(id AS STRING)                       AS form_id,
    NULLIF(TRIM(CAST(title AS STRING)), '')  AS form_title,
    CAST(type AS STRING)                     AS form_type,
    CAST(workspace_id AS STRING)             AS workspace_id,
    CAST(language AS STRING)                 AS language,
    CAST(settings_is_public AS BOOL)         AS is_public,
    CAST(created_at AS TIMESTAMP)            AS created_at,
    CAST(last_updated_at AS TIMESTAMP)       AS last_updated_at
FROM {{ source('typeform', 'form') }}
QUALIFY ROW_NUMBER() OVER (PARTITION BY id ORDER BY _weld_synced DESC) = 1
