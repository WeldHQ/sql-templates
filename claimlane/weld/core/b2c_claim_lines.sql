-- core.claimlane.b2c_claim_lines
-- Every product on every consumer ticket, with the ticket's type, outcome and
-- the refunds booked against the line.
-- Grain: claimlane_account x ticket_id x product_index (one row per claimed
-- product line).
-- Currency: the ticket's currency (the shop currency). Never sum across it.
-- Depends on: staging.claimlane.b2c_ticket, .b2c_ticket_product,
--             .b2c_ticket_product_refund
--
-- This is the line-grain model the other B2C reports read.
--
-- claimed_value is quantity x unit_price: what the claimed goods were sold for.
-- refunded_amount is what was actually refunded on the line, summed over every
-- refund booked against it. The two differ for exchanges, store credit, partial
-- refunds and rejected claims, which is the point of having both.
--
-- Refunds are aggregated to the line BEFORE the join: a line refunded in two
-- steps still contributes its claimed value once.
--
-- TICKET-LEVEL AMOUNTS ARE NOT REPEATED ON LINES. return_price and the refunded
-- original shipping belong to the ticket, so they are only on the ticket's first
-- line (is_first_line_of_ticket), and summing the columns gives each ticket once.

WITH refunds AS (
    SELECT
        claimlane_account,
        ticket_id,
        product_index,
        COUNT(*)                     AS refunds,
        SUM(refunded_quantity)       AS refunded_quantity,
        SUM(refunded_amount)         AS refunded_amount,
        SUM(refunded_shipping_cost)  AS refunded_shipping_cost
    FROM {{staging.claimlane.b2c_ticket_product_refund}}
    GROUP BY 1, 2, 3
)

SELECT
    t.claimlane_account,
    t.organization_id,
    t.ticket_id,
    p.product_index,
    p.product_index = MIN(p.product_index) OVER (
        PARTITION BY t.claimlane_account, t.ticket_id
    )                                                AS is_first_line_of_ticket,
    t.rma_number,
    DATE(t.created_at)                               AS created_date,
    t.created_at,
    DATE(t.order_at)                                 AS order_date,
    -- How long after the purchase the shopper came back. A spike in short gaps on
    -- one product is usually a quality or description problem.
    DATE_DIFF(DATE(t.created_at), DATE(t.order_at), DAY) AS days_from_order_to_claim,
    t.ticket_type,
    t.channel_type,
    t.return_type,
    t.suggested_solution,
    t.return_automation_status,
    t.return_automation_status = 'automated'         AS is_automated,
    t.is_archived,
    t.entire_order_returned,
    t.consumer_country_code,
    t.order_number,
    t.currency,

    p.product_id,
    p.variant_id,
    p.product_sku,
    p.product_name,
    p.ean,
    p.issue_tag,
    p.order_line_type,
    p.quantity                                        AS claimed_quantity,
    p.purchased_quantity,
    p.unit_price,
    p.quantity * p.unit_price                         AS claimed_value,
    p.exchange_quantity,

    COALESCE(r.refunds, 0)                            AS refunds,
    COALESCE(r.refunded_quantity, 0)                  AS refunded_quantity,
    COALESCE(r.refunded_amount, 0)                    AS refunded_amount,
    COALESCE(r.refunded_shipping_cost, 0)             AS refunded_shipping_cost,

    CASE WHEN p.product_index = MIN(p.product_index) OVER (
        PARTITION BY t.claimlane_account, t.ticket_id
    ) THEN t.return_price END                         AS return_price,
    CASE WHEN p.product_index = MIN(p.product_index) OVER (
        PARTITION BY t.claimlane_account, t.ticket_id
    ) THEN t.original_shipping_refunded_amount END    AS original_shipping_refunded_amount
FROM {{staging.claimlane.b2c_ticket}} t
INNER JOIN {{staging.claimlane.b2c_ticket_product}} p
    ON  p.claimlane_account = t.claimlane_account
    AND p.ticket_id         = t.ticket_id
LEFT JOIN refunds r
    ON  r.claimlane_account = p.claimlane_account
    AND r.ticket_id         = p.ticket_id
    AND r.product_index     = p.product_index
