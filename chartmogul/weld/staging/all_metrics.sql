-- staging.chartmogul.all_metrics
-- ChartMogul's key metrics, per plan at a daily interval.
-- Grain: one row per plan per day. Values are as at the end of that day.
--
-- Units: mrr, arr, arpa, asp and ltv arrive as integer cents in the account
-- currency and are divided by 100 here. The churn rates are percentages
-- (2.5 means 2.5%), not fractions. customers is a count.
--
-- Additive across plans: mrr, arr. Not additive: customers (a customer on two
-- plans is counted under both), arpa, asp, ltv and the churn rates.

SELECT
    CAST(plan_uuid AS STRING)                     AS plan_uuid,
    CAST(plan_name AS STRING)                     AS plan_name,
    CAST(plan_externalid AS STRING)               AS plan_external_id,
    DATE(CAST(date AS TIMESTAMP))                 AS metric_date,
    CAST(mrr AS NUMERIC) / 100                    AS mrr,
    CAST(arr AS NUMERIC) / 100                    AS arr,
    CAST(arpa AS NUMERIC) / 100                   AS arpa,
    CAST(asp AS NUMERIC) / 100                    AS asp,
    CAST(ltv AS NUMERIC) / 100                    AS ltv,
    CAST(customers AS INT64)                      AS customers,
    CAST(customer_churn_rate AS FLOAT64)          AS customer_churn_rate_pct,
    CAST(mrr_churn_rate AS FLOAT64)               AS mrr_churn_rate_pct
FROM {{raw.chartmogul.all_metrics}}
WHERE date IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY plan_uuid, date ORDER BY _weld_synced DESC) = 1
