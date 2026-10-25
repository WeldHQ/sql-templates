-- pipeline_flow_daily adds up to opportunity_pipeline.
--
-- Every opportunity is created on exactly one day, and every closed one with a
-- close date inside the spine is won or lost on exactly one day. If the spine,
-- the owner list or the currency split drops or duplicates rows, the totals
-- below disagree and the mismatching org is returned.

WITH flow AS (
    SELECT
        salesforce_org,
        SUM(opportunities_created) AS created,
        SUM(opportunities_won)     AS won,
        SUM(opportunities_lost)    AS lost,
        MAX(date_day)              AS last_day
    FROM {{ ref('core_salesforce__pipeline_flow_daily') }}
    GROUP BY 1
),

pipeline AS (
    SELECT
        p.salesforce_org,
        COUNT(*)                                                    AS created,
        COUNTIF(p.is_won  AND p.close_date <= f.last_day)           AS won,
        COUNTIF(p.is_lost AND p.close_date <= f.last_day)           AS lost
    FROM {{ ref('core_salesforce__opportunity_pipeline') }} p
    JOIN flow f
      ON f.salesforce_org = p.salesforce_org
    GROUP BY 1
)

SELECT
    p.salesforce_org,
    p.created AS pipeline_created, f.created AS flow_created,
    p.won     AS pipeline_won,     f.won     AS flow_won,
    p.lost    AS pipeline_lost,    f.lost    AS flow_lost
FROM pipeline p
JOIN flow f
  ON f.salesforce_org = p.salesforce_org
WHERE p.created <> f.created
   OR p.won     <> f.won
   OR p.lost    <> f.lost
