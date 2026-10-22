-- core_younium__subscription_mrr_movements
-- Younium's CMRR movements per subscription per month: the drill-down behind the
-- monthly CMRR bridge.
-- Grain: month x order number. Month is the calendar month of the booking's
-- effective date (UTC).
--
-- Movements are Younium's own booking classifications, not re-derived from
-- charges: NewCustomer, Expansion, Contraction, CustomerChurn and Reactivate map to
-- the five columns; NoChange, SplitOrder and anything else go to other_cmrr.
-- Amounts are the booking's CMRR change in the Younium base currency, signed as
-- Younium records it (contraction and churn are expected to be negative; see
-- tests/assert_movement_signs_match_classification.sql).
--
-- The order-currency CMRR change is kept alongside, for orders billed in another
-- currency.

WITH bookings AS (
    SELECT
        DATE_TRUNC(DATE(effective_at), MONTH) AS month,
        order_number,
        order_currency,
        classification_type,
        cmrr_change,
        cmrr_change_base,
        acv_change_base
    FROM {{ ref('stg_younium__booking') }}
    WHERE effective_at IS NOT NULL
),

per_order AS (
    SELECT
        month,
        order_number,
        -- An order keeps one currency for its lifetime; MAX picks it without
        -- adding it to the grain.
        MAX(order_currency)                                              AS order_currency,
        SUM(IF(classification_type = 'NewCustomer', cmrr_change_base, 0))   AS new_customer_cmrr,
        SUM(IF(classification_type = 'Expansion', cmrr_change_base, 0))     AS expansion_cmrr,
        SUM(IF(classification_type = 'Contraction', cmrr_change_base, 0))   AS contraction_cmrr,
        SUM(IF(classification_type = 'CustomerChurn', cmrr_change_base, 0)) AS churned_cmrr,
        SUM(IF(classification_type = 'Reactivate', cmrr_change_base, 0))    AS reactivation_cmrr,
        SUM(IF(classification_type IN ('NewCustomer', 'Expansion', 'Contraction', 'CustomerChurn', 'Reactivate'),
               0, COALESCE(cmrr_change_base, 0)))                        AS other_cmrr,
        SUM(COALESCE(cmrr_change_base, 0))                               AS net_cmrr_change,
        SUM(COALESCE(cmrr_change, 0))                                    AS net_cmrr_change_order_currency,
        SUM(COALESCE(acv_change_base, 0))                                AS net_acv_change,
        COUNTIF(classification_type = 'NewCustomer')                     AS new_customer_bookings,
        COUNTIF(classification_type = 'CustomerChurn')                   AS churn_bookings,
        COUNTIF(classification_type = 'Reactivate')                      AS reactivation_bookings,
        COUNT(*)                                                         AS bookings
    FROM bookings
    GROUP BY month, order_number
)

SELECT
    p.month,
    p.order_number,
    s.subscription_id,
    s.description       AS subscription_description,
    s.status            AS subscription_status,
    s.external_crm_id,
    p.order_currency,
    p.new_customer_cmrr,
    p.expansion_cmrr,
    p.contraction_cmrr,
    p.churned_cmrr,
    p.reactivation_cmrr,
    p.other_cmrr,
    p.net_cmrr_change,
    p.net_cmrr_change_order_currency,
    p.net_acv_change,
    p.new_customer_bookings,
    p.churn_bookings,
    p.reactivation_bookings,
    p.bookings
FROM per_order p
-- staging.younium.subscription is one row per order_number, so this cannot fan out.
LEFT JOIN {{ ref('stg_younium__subscription') }} s USING (order_number)
