-- core.traede.production_order_status
-- Every production order line with what has been received, what is still
-- outstanding, and how far the supplier's dates have slipped.
-- Grain: one row per traede_account x production order line.
-- Depends on: staging.traede.production_order, .production_order_line, .variant, .product
--
-- This is the inbound side of the order book: what is coming from suppliers, when,
-- and whether it is late. Join to core.traede.order_book on variant_id to see open
-- customer demand against incoming supply.
--
-- SLIPPAGE compares the current expected arrival with the date originally
-- promised. Positive means later than promised. A production order that was never
-- re-planned has both dates equal and a slippage of zero, not NULL.
--
-- OVERDUE means the expected arrival has passed and units are still outstanding on
-- an order that is not received, booked or closed. Statuses are Traede's own
-- enum; an account with custom workflows may need to extend the list.
--
-- Costs are in the supplier's currency, which the connector does not sync. Do not
-- sum outstanding_cost_amount across suppliers that invoice in different
-- currencies.

SELECT
    po.traede_account,
    po.production_order_id,
    po.production_order_number,
    l.production_order_line_id,
    po.status,
    po.supplier_id,

    l.product_id,
    p.item_number,
    p.product_name,
    l.variant_id,
    v.sku,

    DATE(po.created_at)                     AS order_date,
    po.original_expected_departure_date,
    po.expected_departure_date,
    po.original_expected_arrival_date,
    po.expected_arrival_date,
    DATE_DIFF(po.expected_arrival_date, po.original_expected_arrival_date, DAY) AS arrival_slippage_days,

    l.quantity_ordered,
    l.quantity_in_production,
    l.quantity_in_delivery,
    l.quantity_on_the_way,
    l.quantity_received,
    GREATEST(COALESCE(l.quantity_ordered, 0) - COALESCE(l.quantity_received, 0), 0) AS quantity_outstanding,

    l.unit_cost,
    l.line_cost_amount,
    GREATEST(COALESCE(l.quantity_ordered, 0) - COALESCE(l.quantity_received, 0), 0)
        * l.unit_cost                       AS outstanding_cost_amount,

    -- COALESCE because a NULL expected arrival would make the flag NULL, and a
    -- downstream WHERE NOT is_overdue would drop the row. No date means not overdue.
    COALESCE(
        po.expected_arrival_date < CURRENT_DATE()
        AND COALESCE(l.quantity_ordered, 0) > COALESCE(l.quantity_received, 0)
        AND COALESCE(po.status, 'open') NOT IN ('received', 'booked', 'closed'),
        FALSE
    ) AS is_overdue
FROM {{staging.traede.production_order_line}} l
JOIN {{staging.traede.production_order}} po
  ON po.traede_account      = l.traede_account
 AND po.production_order_id = l.production_order_id
LEFT JOIN {{staging.traede.variant}} v
       ON v.traede_account = l.traede_account
      AND v.variant_id     = l.variant_id
LEFT JOIN {{staging.traede.product}} p
       ON p.traede_account = l.traede_account
      AND p.product_id     = l.product_id
