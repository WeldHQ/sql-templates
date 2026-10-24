-- core_chargebee__mrr_movements
-- The MRR bridge by month: opening MRR, new, expansion, contraction, churn,
-- reactivation, closing MRR, plus customer counts. Chargebee's "MRR movements"
-- view, rebuilt from invoices.
--
-- Grain: month x currency. Currency: the invoice currency, major units. Do not
-- add rows of different currencies together; convert first (see the README).
-- Depends on: core.chargebee.mrr_by_customer_month
--
-- All movement columns are sums of the customer-level columns, so this model
-- reconciles exactly to mrr_by_customer_month. Churn and contraction are
-- negative, so the bridge is plain addition:
--   beginning_mrr + new + expansion + contraction + churned + reactivation = ending_mrr
--
-- Rates are computed from the summed amounts (ratio of sums), never averaged
-- across customers.

WITH by_month AS (
    SELECT
        month,
        currency,
        SUM(beginning_mrr)                          AS beginning_mrr,
        SUM(new_mrr)                                AS new_mrr,
        SUM(expansion_mrr)                          AS expansion_mrr,
        SUM(contraction_mrr)                        AS contraction_mrr,
        SUM(churned_mrr)                            AS churned_mrr,
        SUM(reactivation_mrr)                       AS reactivation_mrr,
        SUM(ending_mrr)                             AS ending_mrr,
        COUNTIF(beginning_mrr > 0)                  AS beginning_customers,
        COUNTIF(movement_type = 'new')              AS new_customers,
        COUNTIF(movement_type = 'reactivation')     AS reactivated_customers,
        COUNTIF(movement_type = 'churn')            AS churned_customers,
        COUNTIF(movement_type = 'expansion')        AS expanded_customers,
        COUNTIF(movement_type = 'contraction')      AS contracted_customers,
        COUNTIF(ending_mrr > 0)                     AS ending_customers,
        LOGICAL_OR(is_current_month)                AS is_current_month
    FROM {{ ref('core_chargebee__mrr_by_customer_month') }}
    GROUP BY 1, 2
)

SELECT
    month,
    currency,
    beginning_mrr,
    new_mrr,
    expansion_mrr,
    contraction_mrr,
    churned_mrr,
    reactivation_mrr,
    ending_mrr,
    ending_mrr - beginning_mrr                                  AS net_new_mrr,
    ending_mrr * 12                                             AS ending_arr,
    beginning_customers,
    new_customers,
    reactivated_customers,
    churned_customers,
    expanded_customers,
    contracted_customers,
    ending_customers,
    -- Share of opening MRR lost to churn and contraction, and kept net of
    -- expansion. NULL in a month that opened with no MRR.
    SAFE_DIVIDE(-(churned_mrr + contraction_mrr), beginning_mrr) AS gross_mrr_churn_rate,
    SAFE_DIVIDE(beginning_mrr + expansion_mrr + contraction_mrr + churned_mrr,
                beginning_mrr)                                   AS net_mrr_retention,
    SAFE_DIVIDE(churned_customers, beginning_customers)          AS customer_churn_rate,
    is_current_month
FROM by_month
