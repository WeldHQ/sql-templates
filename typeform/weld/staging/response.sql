-- staging.typeform.response
-- Thin wrapper over raw `response`. One row per submitted response.
--
-- COMPLETED RESPONSES ONLY: only submitted responses are synced. Partial and
-- started-but-not-submitted responses are not, and neither are form views. Completion rate
-- and drop-off cannot be computed from this connector; use Typeform's own Results
-- page for those.
--
-- Timestamps are UTC, as Typeform returns them.

SELECT
    'account_1'                              AS typeform_account,
    CAST(form_id AS STRING)                  AS form_id,
    CAST(token AS STRING)                    AS response_token,
    CAST(landing_id AS STRING)               AS landing_id,
    CAST(landed_at AS TIMESTAMP)             AS landed_at,
    CAST(submitted_at AS TIMESTAMP)          AS submitted_at,
    -- Only set when the form uses Typeform's score variable (quizzes, lead scoring).
    CAST(calculated_score AS FLOAT64)        AS calculated_score,
    -- Hidden fields stay a JSON string: their names are chosen per form.
    CAST(hidden AS STRING)                   AS hidden_fields_json,
    CAST(metadata_platform AS STRING)        AS platform,
    CAST(metadata_browser AS STRING)         AS browser,
    CAST(metadata_referer AS STRING)         AS referer,
    CAST(metadata_network_id AS STRING)      AS network_id
FROM {{raw.typeform.response}}
QUALIFY ROW_NUMBER() OVER (PARTITION BY form_id, token ORDER BY _weld_synced DESC) = 1
