-- The daily rep series must count every call exactly once. A difference means the
-- rep spine dropped someone (a call owned by a user missing from the user stream
-- still gets a row under its own id, so this should not happen) or the date spine
-- is short. Returns zero rows when they agree.

WITH daily AS (
    SELECT gong_account, SUM(calls) AS calls
    FROM {{ ref('core_gong__rep_call_activity_by_day') }}
    GROUP BY 1
),

calls AS (
    SELECT gong_account, COUNT(*) AS calls
    FROM {{ ref('core_gong__calls') }}
    WHERE started_at IS NOT NULL
    GROUP BY 1
)

SELECT
    COALESCE(d.gong_account, c.gong_account) AS gong_account,
    d.calls AS daily_calls,
    c.calls AS call_rows
FROM daily d
FULL OUTER JOIN calls c USING (gong_account)
WHERE COALESCE(d.calls, 0) <> COALESCE(c.calls, 0)
