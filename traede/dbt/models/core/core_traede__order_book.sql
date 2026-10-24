-- core_traede__order_book
-- Every sales order line with what has been shipped and invoiced against it, and
-- what is still open.
-- Grain: one row per traede_account x order x variant (an order line).
-- Depends on: staging.traede.order, .order_line, .customer, .variant, .product
--
-- This is the wholesale order book: pre-orders taken at a trade show or in the B2B
-- shop, waiting for stock to arrive and ship. Sum open_net_amount for the value of
-- confirmed orders not yet sent; group by created or approved date for order
-- intake.
--
-- CURRENT STATE. The connector syncs the order as it is now, so the book cannot be
-- rebuilt for a past date. Materialise this model on a schedule and keep the runs
-- if you want to trend it.
--
-- WHAT COUNTS AS OPEN: an approved order that is not cancelled, with units ordered
-- that have not yet been shipped. Traede's `shipped` rises when units are sent to
-- the warehouse for picking, so "open" here means not yet released to the
-- warehouse. Draft and selection orders (internal_status) are returned but never
-- open, because they are not confirmed yet.
--
-- REMOVED LINES. If a line is deleted from an order in Traede, whether its row
-- disappears from the warehouse depends on the sync: a full re-sync with soft
-- deletes enabled marks it deleted, an incremental sync may leave it in place. If the
-- order book looks too high for a handful of edited orders, that is the first
-- place to look.

SELECT
    o.traede_account,
    o.order_id,
    o.order_number,
    l.variant_id,
    l.product_id,
    p.item_number,
    p.product_name,
    v.sku,

    o.order_type,
    o.internal_status,
    o.status,
    o.is_cancelled,
    o.is_archived,
    o.currency,
    DATE(o.created_at)  AS order_date,
    DATE(o.approved_at) AS approved_date,

    o.customer_id,
    c.customer_number,
    c.customer_name,
    c.customer_country,
    o.delivery_country,

    l.quantity_ordered,
    l.quantity_shipped,
    l.quantity_invoiced,
    l.unit_net_price,
    l.line_net_amount,

    -- Never negative: Traede can ship more than ordered on a re-sized line, and an
    -- over-shipment is not negative backlog.
    GREATEST(COALESCE(l.quantity_ordered, 0) - COALESCE(l.quantity_shipped, 0), 0)  AS quantity_unshipped,
    GREATEST(COALESCE(l.quantity_ordered, 0) - COALESCE(l.quantity_invoiced, 0), 0) AS quantity_uninvoiced,

    -- COALESCE so a NULL internal_status reads as not open rather than NULL.
    COALESCE(
        o.internal_status = 'approved'
        AND NOT o.is_cancelled
        AND COALESCE(l.quantity_ordered, 0) > COALESCE(l.quantity_shipped, 0),
        FALSE
    ) AS is_open,

    CASE
        WHEN o.internal_status = 'approved' AND NOT o.is_cancelled
        THEN GREATEST(COALESCE(l.quantity_ordered, 0) - COALESCE(l.quantity_shipped, 0), 0)
             * l.unit_net_price
        ELSE 0
    END AS open_net_amount
FROM {{ ref('stg_traede__order_line') }} l
JOIN {{ ref('stg_traede__order') }} o
  ON o.traede_account = l.traede_account
 AND o.order_id       = l.order_id
LEFT JOIN {{ ref('stg_traede__customer') }} c
       ON c.traede_account = o.traede_account
      AND c.customer_id    = o.customer_id
LEFT JOIN {{ ref('stg_traede__variant') }} v
       ON v.traede_account = l.traede_account
      AND v.variant_id     = l.variant_id
LEFT JOIN {{ ref('stg_traede__product') }} p
       ON p.traede_account = l.traede_account
      AND p.product_id     = l.product_id
