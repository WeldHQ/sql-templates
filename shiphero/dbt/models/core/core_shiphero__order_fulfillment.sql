-- core_shiphero__order_fulfillment
-- Every order with when it shipped, whether it met its required ship date, what
-- the labels cost and what the customer was charged for shipping.
-- Grain: one row per shiphero_account x order.
-- Depends on: staging.shiphero.order, .order_line_item, .order_shipping_line,
--             .shipment, .shipment_shipping_label
--
-- This is the order-level SLA view: ShipHero's "orders shipped late" and
-- "time to ship" questions, plus shipping cost per order. fulfillment_by_day reads
-- it for the daily on-time rate.
--
-- Every child table is aggregated to the order BEFORE it is joined. An order with
-- three shipments and five line items would otherwise produce fifteen rows and
-- triple the units and quintuple the label cost.
--
-- SHIPPED means a shipment exists. first_shipped_at is the earliest shipment's
-- creation time, which is when the first package was labelled.
--
-- ON TIME compares the date of the first shipment with ShipHero's
-- required_ship_date. It is NULL, deliberately, for orders without a required ship
-- date or not shipped yet: there is nothing to be on time against. Use
-- is_late_unshipped for open orders already past their date; orders marked
-- fulfilled without a synced shipment (shipped outside ShipHero) are not counted
-- as late.
--
-- TIME ZONE: timestamps are UTC as delivered. A warehouse in a US time zone
-- will see late-evening shipments on the next UTC day; convert with
-- DATETIME(ts, 'America/New_York') if same-day SLAs are measured locally.

WITH lines AS (
    SELECT
        shiphero_account,
        order_id,
        COUNT(*)              AS line_items,
        SUM(quantity)         AS units_ordered,
        SUM(quantity_shipped) AS units_shipped,
        SUM(backorder_quantity) AS units_backordered
    FROM {{ ref('stg_shiphero__order_line_item') }}
    GROUP BY 1, 2
),

shipments AS (
    SELECT
        shiphero_account,
        order_id,
        COUNT(*)                                        AS shipments,
        SUM(total_packages)                             AS packages,
        MIN(shipped_at)                                 AS first_shipped_at,
        MAX(shipped_at)                                 AS last_shipped_at,
        -- Warehouse of the first shipment, so the order can be attributed to one
        -- warehouse in fulfillment_by_day.
        ARRAY_AGG(warehouse_id ORDER BY shipped_at LIMIT 1)[SAFE_OFFSET(0)] AS first_shipment_warehouse_id
    FROM {{ ref('stg_shiphero__shipment') }}
    GROUP BY 1, 2
),

labels AS (
    SELECT
        shiphero_account,
        order_id,
        COUNTIF(NOT is_refunded)                         AS labels,
        COUNTIF(is_refunded)                             AS refunded_labels,
        -- Refunded labels were voided with the carrier and cost nothing.
        SUM(CASE WHEN NOT is_refunded THEN label_cost END) AS label_cost
    FROM {{ ref('stg_shiphero__shipment_shipping_label') }}
    GROUP BY 1, 2
),

shipping_charged AS (
    SELECT
        shiphero_account,
        order_id,
        SUM(shipping_charged)          AS shipping_charged,
        ANY_VALUE(requested_method)    AS requested_method
    FROM {{ ref('stg_shiphero__order_shipping_line') }}
    GROUP BY 1, 2
)

SELECT
    o.shiphero_account,
    o.order_id,
    o.order_number,
    o.account_id,
    o.shop_name,
    o.fulfillment_status,
    COALESCE(o.fulfillment_status IN ('canceled', 'cancelled'), FALSE) AS is_canceled,
    o.is_priority,
    o.currency,
    o.total_price,

    COALESCE(o.order_date, o.created_at)        AS ordered_at,
    DATE(COALESCE(o.order_date, o.created_at))  AS order_date,
    DATE(o.required_ship_date)                  AS required_ship_date,

    COALESCE(l.line_items, 0)        AS line_items,
    COALESCE(l.units_ordered, 0)     AS units_ordered,
    COALESCE(l.units_shipped, 0)     AS units_shipped,
    COALESCE(l.units_backordered, 0) AS units_backordered,

    COALESCE(s.shipments, 0)         AS shipments,
    COALESCE(s.packages, 0)          AS packages,
    s.first_shipped_at,
    s.last_shipped_at,
    DATE(s.first_shipped_at)         AS first_shipped_date,
    s.first_shipment_warehouse_id,
    s.first_shipped_at IS NOT NULL   AS is_shipped,

    TIMESTAMP_DIFF(s.first_shipped_at, COALESCE(o.order_date, o.created_at), MINUTE) / 60.0
                                     AS hours_to_first_shipment,

    CASE
        WHEN s.first_shipped_at IS NULL OR o.required_ship_date IS NULL THEN NULL
        ELSE DATE(s.first_shipped_at) <= DATE(o.required_ship_date)
    END AS is_shipped_on_time,

    COALESCE(
        s.first_shipped_at IS NULL
        AND COALESCE(o.fulfillment_status, '') NOT IN ('canceled', 'cancelled', 'fulfilled')
        AND DATE(o.required_ship_date) < CURRENT_DATE(),
        FALSE
    ) AS is_late_unshipped,

    COALESCE(b.labels, 0)            AS labels,
    COALESCE(b.refunded_labels, 0)   AS refunded_labels,
    b.label_cost,
    c.requested_method,
    c.shipping_charged,
    -- What the customer paid for shipping minus what the labels cost. Negative means
    -- shipping was subsidised on this order.
    c.shipping_charged - b.label_cost AS shipping_margin
FROM {{ ref('stg_shiphero__order') }} o
LEFT JOIN lines l
       ON l.shiphero_account = o.shiphero_account
      AND l.order_id         = o.order_id
LEFT JOIN shipments s
       ON s.shiphero_account = o.shiphero_account
      AND s.order_id         = o.order_id
LEFT JOIN labels b
       ON b.shiphero_account = o.shiphero_account
      AND b.order_id         = o.order_id
LEFT JOIN shipping_charged c
       ON c.shiphero_account = o.shiphero_account
      AND c.order_id         = o.order_id
