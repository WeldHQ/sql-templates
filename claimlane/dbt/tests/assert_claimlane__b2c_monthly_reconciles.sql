-- b2c_claims_by_month holds every ticket and every refund exactly once.
--
-- Ticket counts must match the ticket table and refunded amounts must match the
-- line model, per account and currency. A gap means the month spine dropped or
-- duplicated rows, usually after changing the grain on one side of its join.

WITH source AS (
    SELECT
        t.claimlane_account,
        t.currency,
        COUNT(*) AS tickets
    FROM {{ ref('stg_claimlane__b2c_ticket') }} t
    WHERE t.created_at IS NOT NULL
    GROUP BY 1, 2
),

refunds AS (
    SELECT
        claimlane_account,
        currency,
        SUM(refunded_amount) AS refunded_amount
    FROM {{ ref('core_claimlane__b2c_claim_lines') }}
    WHERE created_date IS NOT NULL
    GROUP BY 1, 2
),

monthly AS (
    SELECT
        claimlane_account,
        currency,
        SUM(tickets)         AS tickets,
        SUM(refunded_amount) AS refunded_amount
    FROM {{ ref('core_claimlane__b2c_claims_by_month') }}
    GROUP BY 1, 2
)

SELECT
    s.claimlane_account,
    s.currency,
    s.tickets,
    m.tickets          AS monthly_tickets,
    r.refunded_amount,
    m.refunded_amount  AS monthly_refunded_amount
FROM source s
LEFT JOIN refunds r
    ON  r.claimlane_account = s.claimlane_account
    AND r.currency IS NOT DISTINCT FROM s.currency
LEFT JOIN monthly m
    ON  m.claimlane_account = s.claimlane_account
    AND m.currency IS NOT DISTINCT FROM s.currency
WHERE s.tickets <> COALESCE(m.tickets, 0)
   OR ABS(COALESCE(r.refunded_amount, 0) - COALESCE(m.refunded_amount, 0)) > 0.01
