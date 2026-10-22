-- core.chartmogul.customer_mrr_movements
-- ChartMogul's MRR movements per customer per month: the drill-down behind the
-- monthly MRR bridge.
-- Grain: month x customer x currency. Month is the calendar month of the activity
-- date in UTC.
--
-- These are ChartMogul's own classifications, not re-derived: each activity's type
-- (new_biz, expansion, contraction, churn, reactivation) decides the column and
-- its signed activity_mrr_movement is the amount. Contraction and churn are
-- therefore negative, and net_mrr_movement is a plain sum.
--
-- Amounts are in major units of the ChartMogul account currency (staging divides
-- ChartMogul's cents by 100).

WITH activities AS (
    SELECT
        DATE_TRUNC(DATE(activity_at), MONTH) AS month,
        customer_uuid,
        currency,
        activity_type,
        mrr_movement
    FROM {{staging.chartmogul.customer_activities}}
),

per_customer AS (
    SELECT
        month,
        customer_uuid,
        currency,
        SUM(IF(activity_type = 'new_biz', mrr_movement, 0))      AS new_business_mrr,
        SUM(IF(activity_type = 'expansion', mrr_movement, 0))    AS expansion_mrr,
        SUM(IF(activity_type = 'contraction', mrr_movement, 0))  AS contraction_mrr,
        SUM(IF(activity_type = 'churn', mrr_movement, 0))        AS churned_mrr,
        SUM(IF(activity_type = 'reactivation', mrr_movement, 0)) AS reactivation_mrr,
        SUM(IF(activity_type NOT IN ('new_biz', 'expansion', 'contraction', 'churn', 'reactivation')
               OR activity_type IS NULL, mrr_movement, 0))      AS other_mrr,
        SUM(mrr_movement)                                        AS net_mrr_movement,
        COUNTIF(activity_type = 'new_biz')                       AS new_business_activities,
        COUNTIF(activity_type = 'churn')                         AS churn_activities,
        COUNTIF(activity_type = 'reactivation')                  AS reactivation_activities,
        COUNT(*)                                                 AS activities
    FROM activities
    GROUP BY month, customer_uuid, currency
)

SELECT
    p.month,
    p.customer_uuid,
    c.customer_external_id,
    c.customer_name,
    c.company,
    c.country,
    p.currency,
    p.new_business_mrr,
    p.expansion_mrr,
    p.contraction_mrr,
    p.churned_mrr,
    p.reactivation_mrr,
    p.other_mrr,
    p.net_mrr_movement,
    p.new_business_activities,
    p.churn_activities,
    p.reactivation_activities,
    p.activities
FROM per_customer p
-- staging.chartmogul.customers is one row per customer_uuid, so this cannot fan out.
LEFT JOIN {{staging.chartmogul.customers}} c USING (customer_uuid)
