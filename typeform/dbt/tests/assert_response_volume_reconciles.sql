-- The daily series must account for every submitted response, once.
--
-- Guards both directions: the spine dropping responses (a form missing from the
-- form list, a date outside the spine) and the form join fanning out (a form id
-- appearing twice in staging, for example after a second account is unioned in
-- without changing the typeform_account label).

WITH series AS (
    SELECT typeform_account, form_id, SUM(responses) AS responses
    FROM {{ ref('core_typeform__response_volume') }}
    GROUP BY 1, 2
),

source AS (
    SELECT typeform_account, form_id, COUNT(*) AS responses
    FROM {{ ref('stg_typeform__response') }}
    WHERE submitted_at IS NOT NULL
    GROUP BY 1, 2
)

SELECT
    COALESCE(s.typeform_account, x.typeform_account) AS typeform_account,
    COALESCE(s.form_id, x.form_id)                   AS form_id,
    s.responses AS series_responses,
    x.responses AS source_responses
FROM series s
FULL OUTER JOIN source x
             ON x.typeform_account = s.typeform_account
            AND x.form_id          = s.form_id
WHERE COALESCE(s.responses, -1) <> COALESCE(x.responses, -1)
