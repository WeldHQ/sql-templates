-- stg_qualtrics__survey
-- Thin wrapper over raw `survey`. One row per survey (qualtrics_account).
-- The stream is a full read, so a deleted survey disappears on the next sync.

SELECT
    'account_1'                              AS qualtrics_account,
    CAST(id AS STRING)                       AS survey_id,
    NULLIF(TRIM(CAST(name AS STRING)), '')   AS survey_name,
    CAST(owner_id AS STRING)                 AS owner_id,
    CAST(is_active AS BOOL)                  AS is_active,
    CAST(creation_date AS TIMESTAMP)         AS created_at,
    CAST(last_modified_date AS TIMESTAMP)    AS last_modified_at
FROM {{ source('qualtrics', 'survey') }}
QUALIFY ROW_NUMBER() OVER (PARTITION BY id ORDER BY _weld_synced DESC) = 1
