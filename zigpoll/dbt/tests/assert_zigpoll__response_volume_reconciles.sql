-- The daily series must account for every answer on a non-synthetic poll, once.
--
-- Guards the spine dropping answers and the poll join fanning out, for example
-- after a second account is unioned into staging without changing the
-- zigpoll_account label.

WITH series AS (
    SELECT zigpoll_account, poll_id, SUM(answers) AS answers
    FROM {{ ref('core_zigpoll__response_volume') }}
    GROUP BY 1, 2
),

source AS (
    SELECT r.zigpoll_account, r.poll_id, COUNT(*) AS answers
    FROM {{ ref('stg_zigpoll__response') }} r
    INNER JOIN {{ ref('stg_zigpoll__poll') }} p
            ON p.zigpoll_account = r.zigpoll_account
           AND p.poll_id         = r.poll_id
    WHERE NOT p.is_synthetic
      AND r.created_at IS NOT NULL
    GROUP BY 1, 2
)

SELECT
    COALESCE(s.zigpoll_account, x.zigpoll_account) AS zigpoll_account,
    COALESCE(s.poll_id, x.poll_id)                 AS poll_id,
    s.answers AS series_answers,
    x.answers AS source_answers
FROM series s
FULL OUTER JOIN source x
             ON x.zigpoll_account = s.zigpoll_account
            AND x.poll_id         = s.poll_id
WHERE COALESCE(s.answers, 0) <> COALESCE(x.answers, 0)
