-- One row per call. A duplicate means a child-table join in core_gong__calls fanned
-- out, which would also inflate talk time and every count built on top.

SELECT gong_account, call_id, COUNT(*) AS rows_per_call
FROM {{ ref('core_gong__calls') }}
GROUP BY 1, 2
HAVING COUNT(*) > 1
