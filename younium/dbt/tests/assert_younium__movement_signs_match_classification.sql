-- Bookings are modelled as signed CMRR changes: new customers, expansion and
-- reactivation add CMRR, contraction and churn remove it. Rows returned here mean
-- either a booking was reclassified by hand in Younium, or the sign convention in
-- your tenant differs; check those bookings in Younium before trusting the bridge.

SELECT *
FROM {{ ref('core_younium__subscription_mrr_movements') }}
WHERE new_customer_cmrr < 0
   OR expansion_cmrr < 0
   OR reactivation_cmrr < 0
   OR contraction_cmrr > 0
   OR churned_cmrr > 0
