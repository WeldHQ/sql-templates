-- Deal totals in company_360 add up to deal_pipeline.
--
-- company_360 counts every deal against exactly one company. If that ever stops
-- being true (a deal attributed to every associated company), won and open amounts
-- per company still look plausible but sum to more than the pipeline. Compares the
-- two totals over deals that have a company.

WITH by_company AS (
    SELECT
        SUM(deals_total) AS deals_total,
        ROUND(SUM(won_amount), 2)  AS won_amount,
        ROUND(SUM(open_amount), 2) AS open_amount
    FROM {{ ref('core_hubspot_v2__company_360') }}
),

by_deal AS (
    SELECT
        COUNT(*) AS deals_total,
        ROUND(COALESCE(SUM(won_amount), 0), 2)  AS won_amount,
        ROUND(COALESCE(SUM(open_amount), 0), 2) AS open_amount
    FROM {{ ref('core_hubspot_v2__deal_pipeline') }}
    -- Only deals whose company still exists in the company table.
    WHERE company_id IN (SELECT company_id FROM {{ ref('stg_hubspot_v2__company') }})
)

SELECT *
FROM by_company c
CROSS JOIN by_deal d
WHERE c.deals_total <> d.deals_total
   OR ABS(c.won_amount - d.won_amount) > 0.01
   OR ABS(c.open_amount - d.open_amount) > 0.01
