-- core_claimlane__b2c_claims_by_month
-- Consumer claim volume and refunds per month: how many tickets, of which type,
-- how they were settled, and how much money went back.
-- Grain: month x claimlane_account x organization_id x ticket_type x currency.
-- Currency: the ticket's. Never sum amounts across currency.
-- Depends on: staging.claimlane.b2c_ticket, core.claimlane.b2c_claim_lines
--
-- Tickets land in the month they were CREATED. There is no resolution date in
-- the synced data, so refunds are reported against the month the claim came in,
-- not the month the money left; a March claim refunded in April counts in March.
--
-- TICKETS ARE COUNTED FROM THE TICKET TABLE, amounts from the line model. A
-- ticket with three products is one ticket here, not three, and a ticket whose
-- products did not sync still counts as a ticket.
--
-- refund_rate_of_claimed_value is a ratio of the month's sums, so a large order
-- weighs what it is worth. It is below 1 when claims end in exchanges, store
-- credit, partial refunds or rejection.
--
-- Built on a month spine per organisation, ticket type and currency, from the
-- first month the combination appears to the current month.

WITH tickets AS (
    SELECT
        claimlane_account,
        organization_id,
        COALESCE(ticket_type, '(none)')                  AS ticket_type,
        currency,
        DATE_TRUNC(DATE(created_at), MONTH)              AS month,
        COUNT(*)                                         AS tickets,
        COUNTIF(return_type = 'refund')                  AS refund_tickets,
        COUNTIF(return_type = 'exchange')                AS exchange_tickets,
        COUNTIF(return_type = 'storeCredit')             AS store_credit_tickets,
        COUNTIF(return_type = 'keepProduct')             AS keep_product_tickets,
        COUNTIF(return_automation_status = 'automated')  AS automated_tickets,
        COUNTIF(entire_order_returned)                   AS entire_order_tickets
    FROM {{ ref('stg_claimlane__b2c_ticket') }}
    WHERE created_at IS NOT NULL
    GROUP BY 1, 2, 3, 4, 5
),

lines AS (
    SELECT
        claimlane_account,
        organization_id,
        COALESCE(ticket_type, '(none)')      AS ticket_type,
        currency,
        DATE_TRUNC(created_date, MONTH)      AS month,
        COUNT(*)                             AS claimed_lines,
        SUM(claimed_quantity)                AS claimed_quantity,
        SUM(claimed_value)                   AS claimed_value,
        SUM(refunded_quantity)               AS refunded_quantity,
        SUM(refunded_amount)                 AS refunded_amount,
        SUM(refunded_shipping_cost)          AS refunded_shipping_cost
    FROM {{ ref('core_claimlane__b2c_claim_lines') }}
    WHERE created_date IS NOT NULL
    GROUP BY 1, 2, 3, 4, 5
),

series AS (
    SELECT
        claimlane_account,
        organization_id,
        ticket_type,
        currency,
        MIN(month) AS first_month,
        MAX(month) AS last_month
    FROM tickets
    GROUP BY 1, 2, 3, 4
),

spine AS (
    SELECT
        s.claimlane_account,
        s.organization_id,
        s.ticket_type,
        s.currency,
        m AS month
    FROM series s
    CROSS JOIN UNNEST(GENERATE_DATE_ARRAY(
        s.first_month,
        GREATEST(s.last_month, DATE_TRUNC(CURRENT_DATE(), MONTH)),
        INTERVAL 1 MONTH
    )) AS m
)

SELECT
    s.month,
    s.claimlane_account,
    s.organization_id,
    s.ticket_type,
    s.currency,
    COALESCE(t.tickets, 0)                 AS tickets,
    COALESCE(t.refund_tickets, 0)          AS refund_tickets,
    COALESCE(t.exchange_tickets, 0)        AS exchange_tickets,
    COALESCE(t.store_credit_tickets, 0)    AS store_credit_tickets,
    COALESCE(t.keep_product_tickets, 0)    AS keep_product_tickets,
    COALESCE(t.automated_tickets, 0)       AS automated_tickets,
    COALESCE(t.entire_order_tickets, 0)    AS entire_order_tickets,
    COALESCE(l.claimed_lines, 0)           AS claimed_lines,
    COALESCE(l.claimed_quantity, 0)        AS claimed_quantity,
    COALESCE(l.claimed_value, 0)           AS claimed_value,
    COALESCE(l.refunded_quantity, 0)       AS refunded_quantity,
    COALESCE(l.refunded_amount, 0)         AS refunded_amount,
    COALESCE(l.refunded_shipping_cost, 0)  AS refunded_shipping_cost,
    SAFE_DIVIDE(l.refunded_amount, l.claimed_value) AS refund_rate_of_claimed_value,
    SAFE_DIVIDE(t.automated_tickets, t.tickets)     AS automation_rate
FROM spine s
LEFT JOIN tickets t
    ON  t.claimlane_account = s.claimlane_account
    AND t.organization_id   = s.organization_id
    AND t.ticket_type       = s.ticket_type
    AND t.currency          IS NOT DISTINCT FROM s.currency
    AND t.month             = s.month
LEFT JOIN lines l
    ON  l.claimlane_account = s.claimlane_account
    AND l.organization_id   = s.organization_id
    AND l.ticket_type       = s.ticket_type
    AND l.currency          IS NOT DISTINCT FROM s.currency
    AND l.month             = s.month
