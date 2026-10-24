-- core.chartmogul.mrr_movements
-- The MRR bridge, as ChartMogul's "MRR movements" chart shows it: opening MRR,
-- new business, expansion, contraction, churn, reactivation, closing MRR.
-- Grain: month x currency. Every month from the first activity to the current
-- month is present, including months without movements.
--
-- closing_mrr is the running sum of every movement since the first activity, so
-- it only equals real MRR when the activity history is complete (the first
-- sync pulls all of it). chartmogul_reported_mrr is ChartMogul's own MRR at
-- the last synced day of the month, summed over plans, for reconciliation. The
-- two should agree; a gap usually means ChartMogul restated history after a sync.
--
-- ChartMogul reports every amount in the single account currency, so expect one
-- currency. chartmogul_reported_mrr carries no currency and is joined on month
-- alone; it is in the same account currency.
--
-- Amounts in major units. Contraction and churn are negative.

WITH movements AS (
    SELECT
        month,
        currency,
        SUM(new_business_mrr)        AS new_business_mrr,
        SUM(expansion_mrr)           AS expansion_mrr,
        SUM(contraction_mrr)         AS contraction_mrr,
        SUM(churned_mrr)             AS churned_mrr,
        SUM(reactivation_mrr)        AS reactivation_mrr,
        SUM(other_mrr)               AS other_mrr,
        SUM(net_mrr_movement)        AS net_mrr_movement,
        COUNTIF(new_business_activities > 0) AS new_customers,
        COUNTIF(churn_activities > 0)        AS churned_customers,
        COUNTIF(reactivation_activities > 0) AS reactivated_customers
    FROM {{core.chartmogul.customer_mrr_movements}}
    GROUP BY month, currency
),

month_spine AS (
    SELECT currency, month
    FROM (
        SELECT currency, MIN(month) AS first_month
        FROM movements
        GROUP BY currency
    ),
    UNNEST(GENERATE_DATE_ARRAY(first_month, DATE_TRUNC(CURRENT_DATE(), MONTH), INTERVAL 1 MONTH)) AS month
),

bridge AS (
    SELECT
        s.month,
        s.currency,
        COALESCE(m.new_business_mrr, 0)   AS new_business_mrr,
        COALESCE(m.expansion_mrr, 0)      AS expansion_mrr,
        COALESCE(m.contraction_mrr, 0)    AS contraction_mrr,
        COALESCE(m.churned_mrr, 0)        AS churned_mrr,
        COALESCE(m.reactivation_mrr, 0)   AS reactivation_mrr,
        COALESCE(m.other_mrr, 0)          AS other_mrr,
        COALESCE(m.net_mrr_movement, 0)   AS net_mrr_movement,
        COALESCE(m.new_customers, 0)         AS new_customers,
        COALESCE(m.churned_customers, 0)     AS churned_customers,
        COALESCE(m.reactivated_customers, 0) AS reactivated_customers
    FROM month_spine s
    LEFT JOIN movements m USING (currency, month)
),

-- ChartMogul's own MRR: sum over plans on the last synced day of each month.
reported AS (
    SELECT month, mrr AS chartmogul_reported_mrr
    FROM (
        SELECT
            DATE_TRUNC(metric_date, MONTH) AS month,
            metric_date,
            SUM(mrr)                       AS mrr
        FROM {{staging.chartmogul.all_metrics}}
        GROUP BY 1, 2
    )
    WHERE TRUE
    QUALIFY metric_date = MAX(metric_date) OVER (PARTITION BY month)
)

SELECT
    b.month,
    b.currency,
    COALESCE(SUM(b.net_mrr_movement) OVER (
        PARTITION BY b.currency ORDER BY b.month
        ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
    ), 0)                             AS opening_mrr,
    b.new_business_mrr,
    b.expansion_mrr,
    b.contraction_mrr,
    b.churned_mrr,
    b.reactivation_mrr,
    b.other_mrr,
    b.net_mrr_movement,
    SUM(b.net_mrr_movement) OVER (
        PARTITION BY b.currency ORDER BY b.month
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )                                 AS closing_mrr,
    b.new_customers,
    b.churned_customers,
    b.reactivated_customers,
    r.chartmogul_reported_mrr
FROM bridge b
LEFT JOIN reported r USING (month)
