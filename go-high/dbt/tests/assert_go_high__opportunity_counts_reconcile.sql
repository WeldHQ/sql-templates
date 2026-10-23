-- Every opportunity lands in exactly one row of each core model.
--
-- pipeline_snapshot and opportunity_outcomes_monthly both read the opportunity list and
-- join pipeline and stage names. If a pipeline or stage stops being unique the joins fan
-- out and both models over-count; if the grouping drops a key, they under-count. Both
-- totals must equal the number of opportunities (with a created date, for the second).

WITH expected AS (
    SELECT
        COUNT(*)                        AS all_opportunities,
        COUNTIF(created_at IS NOT NULL) AS dated_opportunities
    FROM {{ ref('stg_go_high__opportunity') }}
),

snapshot AS (
    SELECT SUM(opportunities) AS total FROM {{ ref('core_go_high__pipeline_snapshot') }}
),

outcomes AS (
    SELECT SUM(opportunities) AS total FROM {{ ref('core_go_high__opportunity_outcomes_monthly') }}
)

SELECT e.all_opportunities, s.total AS snapshot_total, e.dated_opportunities, o.total AS outcomes_total
FROM expected e
CROSS JOIN snapshot s
CROSS JOIN outcomes o
WHERE COALESCE(s.total, 0) != e.all_opportunities
   OR COALESCE(o.total, 0) != e.dated_opportunities
