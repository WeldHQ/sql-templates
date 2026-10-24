-- core_younium__mrr_movements
-- The CMRR bridge: opening committed MRR, new customers, expansion, contraction,
-- churn, reactivation, closing CMRR. Recreates the movement breakdown of
-- Younium's CMRR reporting from its bookings.
-- Grain: month. Every month from the first booking to the current month is
-- present, including months without bookings.
--
-- Currency: everything is in the Younium base currency, using Younium's own
-- conversion on each booking. base_currency is read from the accounts table.
--
-- closing_cmrr is the running sum of every booking since the first one, so it only
-- equals real CMRR when the booking history is complete. For the current month,
-- younium_current_cmrr is the sum of Younium's live CMRR over all accounts, for
-- reconciliation.

WITH movements AS (
    SELECT
        month,
        SUM(new_customer_cmrr)  AS new_customer_cmrr,
        SUM(expansion_cmrr)     AS expansion_cmrr,
        SUM(contraction_cmrr)   AS contraction_cmrr,
        SUM(churned_cmrr)       AS churned_cmrr,
        SUM(reactivation_cmrr)  AS reactivation_cmrr,
        SUM(other_cmrr)         AS other_cmrr,
        SUM(net_cmrr_change)    AS net_cmrr_change,
        SUM(net_acv_change)     AS net_acv_change,
        COUNTIF(new_customer_bookings > 0) AS orders_from_new_customers,
        COUNTIF(churn_bookings > 0)        AS orders_churned,
        COUNTIF(reactivation_bookings > 0) AS orders_reactivated
    FROM {{ ref('core_younium__subscription_mrr_movements') }}
    GROUP BY month
),

month_spine AS (
    SELECT month
    FROM UNNEST(GENERATE_DATE_ARRAY(
        (SELECT MIN(month) FROM movements),
        DATE_TRUNC(CURRENT_DATE(), MONTH),
        INTERVAL 1 MONTH
    )) AS month
),

current_cmrr AS (
    SELECT
        MAX(base_currency)  AS base_currency,
        SUM(cmrr_base)      AS younium_current_cmrr
    FROM {{ ref('stg_younium__account') }}
),

bridge AS (
    SELECT
        s.month,
        COALESCE(m.new_customer_cmrr, 0)  AS new_customer_cmrr,
        COALESCE(m.expansion_cmrr, 0)     AS expansion_cmrr,
        COALESCE(m.contraction_cmrr, 0)   AS contraction_cmrr,
        COALESCE(m.churned_cmrr, 0)       AS churned_cmrr,
        COALESCE(m.reactivation_cmrr, 0)  AS reactivation_cmrr,
        COALESCE(m.other_cmrr, 0)         AS other_cmrr,
        COALESCE(m.net_cmrr_change, 0)    AS net_cmrr_change,
        COALESCE(m.net_acv_change, 0)     AS net_acv_change,
        COALESCE(m.orders_from_new_customers, 0) AS orders_from_new_customers,
        COALESCE(m.orders_churned, 0)            AS orders_churned,
        COALESCE(m.orders_reactivated, 0)        AS orders_reactivated
    FROM month_spine s
    LEFT JOIN movements m USING (month)
)

SELECT
    b.month,
    c.base_currency,
    COALESCE(SUM(b.net_cmrr_change) OVER (
        ORDER BY b.month ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
    ), 0)                                     AS opening_cmrr,
    b.new_customer_cmrr,
    b.expansion_cmrr,
    b.contraction_cmrr,
    b.churned_cmrr,
    b.reactivation_cmrr,
    b.other_cmrr,
    b.net_cmrr_change,
    SUM(b.net_cmrr_change) OVER (
        ORDER BY b.month ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )                                         AS closing_cmrr,
    b.net_acv_change,
    b.orders_from_new_customers,
    b.orders_churned,
    b.orders_reactivated,
    IF(b.month = DATE_TRUNC(CURRENT_DATE(), MONTH), c.younium_current_cmrr, NULL) AS younium_current_cmrr
FROM bridge b
-- current_cmrr is a single row.
CROSS JOIN current_cmrr c
