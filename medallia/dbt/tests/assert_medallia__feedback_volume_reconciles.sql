-- The daily series must count every answered feedback record exactly once.
--
-- Guards the spine dropping records (a NULL unit falling out of the unit join, a
-- response date outside the spine) and the unit join fanning out (a unit
-- identifier appearing twice in staging).

WITH series AS (
    SELECT medallia_account, SUM(responses) AS responses
    FROM {{ ref('core_medallia__feedback_volume') }}
    GROUP BY 1
),

source AS (
    SELECT medallia_account, COUNT(*) AS responses
    FROM {{ ref('stg_medallia__feedback') }}
    WHERE responded_at IS NOT NULL
    GROUP BY 1
)

SELECT
    COALESCE(s.medallia_account, x.medallia_account) AS medallia_account,
    s.responses AS series_responses,
    x.responses AS source_responses
FROM series s
FULL OUTER JOIN source x
             ON x.medallia_account = s.medallia_account
WHERE COALESCE(s.responses, 0) <> COALESCE(x.responses, 0)
