-- core_recurly__subscription_churn
-- Every subscription that has ended, why it ended, and how much MRR it was
-- carrying just before. Splits churn into customers who chose to leave and
-- customers lost to failed payments, which the MRR bridge cannot tell apart.
--
-- Grain: one row per expired subscription. A subscription that is canceled but
-- still running until the end of its term is not here yet; it arrives the day it
-- expires. Currency: the subscription currency, major units.
-- Depends on: staging.recurly.subscription, staging.recurly.account,
-- core.recurly.recurring_revenue_lines
--
-- CHURN TYPE, from Recurly's expiration_reason:
--   voluntary            canceled: the customer or an admin ended it
--   involuntary          nonpayment (dunning gave up) or tax_location_invalid
--                        (tax validation failed and the account was never fixed)
--   term_ended           fixed billing cycles ran out without renewal
--   trial_not_converted  a cardless trial, or a gift, ended with no billing info
--   other                any reason not listed above, kept as is in
--                        expiration_reason so it can be mapped
-- is_account_closed is separate: a closed account expires its subscriptions as
-- canceled, so it is a flag on top of the type rather than a type of its own.
--
-- MRR AT EXPIRY is the subscription's MRR on the day before it expired, from the
-- same line items and normalisation as the MRR models, floored at 0. It is 0 for
-- a trial that never converted, and 0 when a termination refunded the last
-- period in full, because the refund credit takes that period back out.
--
-- This model counts subscriptions. The MRR bridge counts customers, so an
-- account that swaps one subscription for another is churn here and an expansion
-- or contraction there. Compare the two by customer, not by row count.

WITH ended AS (
    SELECT
        s.*,
        DATE(s.expires_at) AS expired_on
    FROM {{ ref('stg_recurly__subscription') }} s
    WHERE s.state = 'expired'
      AND s.expires_at IS NOT NULL
),

mrr_before_expiry AS (
    SELECT
        e.subscription_id,
        SUM(l.monthly_amount) AS mrr
    FROM ended e
    JOIN {{ ref('core_recurly__recurring_revenue_lines') }} l
      ON l.subscription_id = e.subscription_id
     AND l.service_start  <= DATE_SUB(e.expired_on, INTERVAL 1 DAY)
     AND l.service_end    >  DATE_SUB(e.expired_on, INTERVAL 1 DAY)
    GROUP BY 1
)

SELECT
    e.subscription_id,
    e.account_id                                            AS customer_id,
    a.customer_name,
    e.plan_id,
    e.currency,
    e.created_at,
    e.activated_at,
    e.canceled_at,
    e.expires_at                                            AS expired_at,
    DATE_TRUNC(e.expired_on, MONTH)                         AS churn_month,
    e.expiration_reason,
    CASE
        WHEN e.expiration_reason = 'canceled'                                THEN 'voluntary'
        WHEN e.expiration_reason IN ('nonpayment', 'non_payment',
                                     'tax_location_invalid')                 THEN 'involuntary'
        WHEN e.expiration_reason IN ('fixed_billing_cycles', 'non_renewing',
                                     'nonrenewing')                          THEN 'term_ended'
        WHEN e.expiration_reason IN ('nonpayment_trial', 'nonpayment_gift')  THEN 'trial_not_converted'
        ELSE 'other'
    END                                                     AS churn_type,
    COALESCE(a.state = 'closed', FALSE)                     AS is_account_closed,
    e.activated_at IS NOT NULL                              AS was_activated,
    DATE_DIFF(e.expired_on, DATE(e.activated_at), DAY)      AS active_days,
    GREATEST(ROUND(COALESCE(m.mrr, 0), 2), 0)               AS mrr_at_expiry
FROM ended e
-- Both joins are on unique keys (account_id, and one aggregated row per
-- subscription), so neither can fan out.
LEFT JOIN {{ ref('stg_recurly__account') }} a
       ON a.account_id = e.account_id
LEFT JOIN mrr_before_expiry m
       ON m.subscription_id = e.subscription_id
