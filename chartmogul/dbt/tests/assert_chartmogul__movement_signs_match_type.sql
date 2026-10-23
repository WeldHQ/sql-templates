-- ChartMogul signs movements by type: new business, expansion and reactivation
-- add MRR; contraction and churn remove it. A row breaking that means the sign
-- convention changed or an activity type was misread.

SELECT *
FROM {{ ref('core_chartmogul__customer_mrr_movements') }}
WHERE new_business_mrr < 0
   OR expansion_mrr < 0
   OR reactivation_mrr < 0
   OR contraction_mrr > 0
   OR churned_mrr > 0
