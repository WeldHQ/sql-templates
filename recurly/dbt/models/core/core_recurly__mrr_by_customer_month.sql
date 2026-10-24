-- core_recurly__mrr_by_customer_month
-- MRR per customer per month, and the movement that took it there: new,
-- expansion, contraction, churn or reactivation.
--
-- Grain: month x customer (Recurly account) x currency. A customer appears from the first month they
-- had MRR, in every month they had MRR, and in the month they churned. Months
-- after a churn with no MRR are left out until the customer comes back.
-- Currency: the invoice currency, major units. A customer billed in two
-- currencies has two rows per month.
-- Depends on: core.recurly.recurring_revenue_lines
--
-- MRR AT A MONTH is the sum of monthly_amount over every recurring line whose
-- service period covers the snapshot date: the last day of the month, or today
-- for the month in progress. A subscription cancelled at the end of its term stops
-- counting the day its last paid period ends; one terminated with a prorated or
-- full refund stops on the day the refund credit starts.
--
-- MOVEMENTS, with beginning_mrr = the previous month's MRR:
--   new           beginning 0, MRR > 0, and never had MRR before
--   reactivation  beginning 0, MRR > 0, had MRR in some earlier month
--   expansion     beginning > 0, MRR higher
--   contraction   beginning > 0, MRR lower but above 0      (stored negative)
--   churn         beginning > 0, MRR 0                      (stored negative)
-- So beginning_mrr + new + expansion + contraction + churn + reactivation =
-- mrr, on every row. tests/assert_recurly__mrr_movements_reconcile.sql checks it.
--
-- Movements are measured per CUSTOMER, which is how most SaaS reporting counts
-- them: a customer moving from plan A to plan B, or replacing one subscription
-- with another, is an expansion or a contraction, not a churn plus a new. For a
-- per-subscription view, group recurring_revenue_lines by `subscription_id`,
-- which Recurly puts on every line item.
--
-- The snapshot uses invoiced line items. A renewal that has not been invoiced yet, or usage
-- billed in arrears, is missing until the invoice exists, so the current month
-- is provisional until month end.

WITH lines AS (
    SELECT * FROM {{ ref('core_recurly__recurring_revenue_lines') }}
),

bounds AS (
    SELECT DATE_TRUNC(MIN(service_start), MONTH) AS first_month FROM lines
),

months AS (
    SELECT
        month,
        LEAST(LAST_DAY(month, MONTH), CURRENT_DATE())   AS snapshot_date
    FROM bounds,
    UNNEST(GENERATE_DATE_ARRAY(
        bounds.first_month,
        DATE_TRUNC(CURRENT_DATE(), MONTH),
        INTERVAL 1 MONTH
    )) AS month
),

snapshot AS (
    SELECT
        m.month,
        l.customer_id,
        l.currency,
        SUM(l.monthly_amount) AS mrr
    FROM months m
    JOIN lines l
      ON l.service_start <= m.snapshot_date
     AND l.service_end   >  m.snapshot_date
    GROUP BY 1, 2, 3
),

first_month AS (
    SELECT customer_id, currency, MIN(month) AS first_mrr_month
    FROM snapshot
    WHERE ROUND(mrr, 2) > 0
    GROUP BY 1, 2
),

-- Every month from the customer's first, so a month with no MRR becomes a zero
-- rather than a gap. A gap would hide the churn.
filled AS (
    SELECT
        f.customer_id,
        f.currency,
        m.month,
        -- Credits can briefly exceed charges in a snapshot (for example a refund
        -- credit covering the same period as a new charge). MRR is floored at 0.
        GREATEST(ROUND(COALESCE(s.mrr, 0), 2), 0) AS mrr
    FROM first_month f
    JOIN months m
      ON m.month >= f.first_mrr_month
    LEFT JOIN snapshot s
           ON s.customer_id = f.customer_id
          AND s.currency    = f.currency
          AND s.month       = m.month
),

with_previous AS (
    SELECT
        *,
        COALESCE(LAG(mrr) OVER w, 0) AS beginning_mrr,
        COALESCE(MAX(mrr) OVER (w ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING), 0)
            AS highest_previous_mrr
    FROM filled
    WINDOW w AS (PARTITION BY customer_id, currency ORDER BY month)
),

classified AS (
    SELECT
        *,
        CASE
            WHEN beginning_mrr = 0 AND mrr > 0 AND highest_previous_mrr = 0 THEN 'new'
            WHEN beginning_mrr = 0 AND mrr > 0                              THEN 'reactivation'
            WHEN beginning_mrr > 0 AND mrr = 0                              THEN 'churn'
            WHEN mrr > beginning_mrr                                        THEN 'expansion'
            WHEN mrr < beginning_mrr                                        THEN 'contraction'
            ELSE 'unchanged'
        END AS movement_type
    FROM with_previous
    WHERE beginning_mrr > 0 OR mrr > 0
)

SELECT
    c.month,
    c.customer_id,
    cu.customer_name,
    c.currency,
    c.movement_type,
    c.beginning_mrr,
    IF(c.movement_type = 'new',          c.mrr, 0)                      AS new_mrr,
    IF(c.movement_type = 'expansion',    c.mrr - c.beginning_mrr, 0)    AS expansion_mrr,
    IF(c.movement_type = 'contraction',  c.mrr - c.beginning_mrr, 0)    AS contraction_mrr,
    IF(c.movement_type = 'churn',        -c.beginning_mrr, 0)           AS churned_mrr,
    IF(c.movement_type = 'reactivation', c.mrr, 0)                      AS reactivation_mrr,
    c.mrr                                                               AS ending_mrr,
    c.mrr * 12                                                          AS ending_arr,
    c.month = DATE_TRUNC(CURRENT_DATE(), MONTH)                         AS is_current_month
FROM classified c
-- account is unique on account_id, so this cannot fan out.
LEFT JOIN {{ ref('stg_recurly__account') }} cu
       ON cu.account_id = c.customer_id
