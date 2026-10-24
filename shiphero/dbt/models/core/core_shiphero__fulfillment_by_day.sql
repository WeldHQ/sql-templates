-- core_shiphero__fulfillment_by_day
-- Fulfilment throughput, shipping cost and on-time rate per warehouse per day.
-- Grain: day x shiphero_account x warehouse.
-- Depends on: staging.shiphero.shipment, .shipment_line_item,
--             .shipment_shipping_label, core.shiphero.order_fulfillment
--
-- Two kinds of measure, each on its own date:
--   Throughput and cost (shipments, packages, units, labels, label_cost) land on
--   the day each SHIPMENT was created, so an order shipped in two goes counts on
--   both days.
--   SLA (orders_first_shipped, orders_shipped_on_time) lands on the day of each
--   order's FIRST shipment and counts each order once, at the warehouse that sent
--   that first shipment.
--
-- Label cost is attached to its shipment and excludes refunded (voided) labels.
-- Average cost per shipment and on-time rate are ratios: compute them in BI as
-- SUM(label_cost) / SUM(shipments) and SUM(orders_shipped_on_time) /
-- SUM(orders_with_required_date) over the window, never as an average of daily
-- ratios.
--
-- Built on a day spine per warehouse so a day without shipments returns zeros.
-- Days are UTC; see order_fulfillment for the time-zone note.

WITH shipment_units AS (
    SELECT shiphero_account, shipment_id, SUM(quantity) AS units
    FROM {{ ref('stg_shiphero__shipment_line_item') }}
    GROUP BY 1, 2
),

shipment_labels AS (
    SELECT
        shiphero_account,
        shipment_id,
        COUNTIF(NOT is_refunded)                           AS labels,
        COUNTIF(is_refunded)                               AS refunded_labels,
        SUM(CASE WHEN NOT is_refunded THEN label_cost END) AS label_cost
    FROM {{ ref('stg_shiphero__shipment_shipping_label') }}
    GROUP BY 1, 2
),

shipments AS (
    -- One row per shipment with its units and label cost, so the daily sum below
    -- cannot fan out.
    SELECT
        DATE(s.shipped_at) AS date,
        s.shiphero_account,
        s.warehouse_id,
        s.shipment_id,
        s.order_id,
        s.total_packages,
        u.units,
        b.labels,
        b.refunded_labels,
        b.label_cost
    FROM {{ ref('stg_shiphero__shipment') }} s
    LEFT JOIN shipment_units u
           ON u.shiphero_account = s.shiphero_account
          AND u.shipment_id      = s.shipment_id
    LEFT JOIN shipment_labels b
           ON b.shiphero_account = s.shiphero_account
          AND b.shipment_id      = s.shipment_id
    WHERE s.shipped_at IS NOT NULL
),

daily AS (
    SELECT
        date,
        shiphero_account,
        warehouse_id,
        COUNT(*)                   AS shipments,
        COUNT(DISTINCT order_id)   AS orders_shipped,
        SUM(total_packages)        AS packages,
        SUM(units)                 AS units_shipped,
        SUM(labels)                AS labels,
        SUM(refunded_labels)       AS refunded_labels,
        SUM(label_cost)            AS label_cost
    FROM shipments
    GROUP BY 1, 2, 3
),

sla AS (
    SELECT
        first_shipped_date            AS date,
        shiphero_account,
        first_shipment_warehouse_id   AS warehouse_id,
        COUNT(*)                                        AS orders_first_shipped,
        COUNTIF(required_ship_date IS NOT NULL)         AS orders_with_required_date,
        COUNTIF(is_shipped_on_time)                     AS orders_shipped_on_time,
        SUM(hours_to_first_shipment)                    AS hours_to_first_shipment_total
    FROM {{ ref('core_shiphero__order_fulfillment') }}
    WHERE is_shipped
    GROUP BY 1, 2, 3
),

series AS (
    SELECT shiphero_account, warehouse_id, MIN(date) AS first_date, MAX(date) AS last_date
    FROM daily
    GROUP BY 1, 2
),

spine AS (
    SELECT s.shiphero_account, s.warehouse_id, d AS date
    FROM series s
    CROSS JOIN UNNEST(GENERATE_DATE_ARRAY(s.first_date, GREATEST(s.last_date, CURRENT_DATE()))) AS d
)

SELECT
    sp.date,
    sp.shiphero_account,
    sp.warehouse_id,
    COALESCE(d.shipments, 0)        AS shipments,
    COALESCE(d.orders_shipped, 0)   AS orders_shipped,
    COALESCE(d.packages, 0)         AS packages,
    COALESCE(d.units_shipped, 0)    AS units_shipped,
    COALESCE(d.labels, 0)           AS labels,
    COALESCE(d.refunded_labels, 0)  AS refunded_labels,
    COALESCE(d.label_cost, 0)       AS label_cost,
    COALESCE(x.orders_first_shipped, 0)      AS orders_first_shipped,
    COALESCE(x.orders_with_required_date, 0) AS orders_with_required_date,
    COALESCE(x.orders_shipped_on_time, 0)    AS orders_shipped_on_time,
    -- Sum, not average: divide by orders_first_shipped in BI for mean time to ship.
    COALESCE(x.hours_to_first_shipment_total, 0) AS hours_to_first_shipment_total
FROM spine sp
LEFT JOIN daily d
       ON d.shiphero_account = sp.shiphero_account
      AND d.warehouse_id IS NOT DISTINCT FROM sp.warehouse_id
      AND d.date             = sp.date
LEFT JOIN sla x
       ON x.shiphero_account = sp.shiphero_account
      AND x.warehouse_id IS NOT DISTINCT FROM sp.warehouse_id
      AND x.date             = sp.date
