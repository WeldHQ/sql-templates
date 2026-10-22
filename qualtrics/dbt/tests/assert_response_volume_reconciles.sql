-- The daily series must account for every recorded response that is not a test,
-- preview or spam, once.
--
-- Guards the spine dropping responses and the survey join fanning out, for example
-- after a second account is unioned into staging without changing the
-- qualtrics_account label.

WITH series AS (
    SELECT qualtrics_account, survey_id, SUM(responses) AS responses
    FROM {{ ref('core_qualtrics__response_volume') }}
    GROUP BY 1, 2
),

source AS (
    SELECT qualtrics_account, survey_id, COUNT(*) AS responses
    FROM {{ ref('stg_qualtrics__survey_response') }}
    WHERE recorded_at IS NOT NULL
      AND NOT is_test_or_spam
    GROUP BY 1, 2
)

SELECT
    COALESCE(s.qualtrics_account, x.qualtrics_account) AS qualtrics_account,
    COALESCE(s.survey_id, x.survey_id)                 AS survey_id,
    s.responses AS series_responses,
    x.responses AS source_responses
FROM series s
FULL OUTER JOIN source x
             ON x.qualtrics_account = s.qualtrics_account
            AND x.survey_id         = s.survey_id
WHERE COALESCE(s.responses, 0) <> COALESCE(x.responses, 0)
