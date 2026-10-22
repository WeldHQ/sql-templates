-- core_cargoson__shipments
-- Every booking as a shipment: lane, carrier, service, agreed freight price,
-- goods weight, and how its transit went against the carrier's estimate.
-- Grain: one row per cargoson_account x booking_reference.
-- Currency: freight_currency, per booking. Never sum freight_price across it.
-- Depends on: staging.cargoson.booking, staging.cargoson.booking_row
--
-- This is the shipment-grain model the other reports read. Classify once here.
--
-- STATUS. Cargoson has two status fields. `status` is the booking workflow
-- (new, requested, quoted, booked, withdrawn, declined, lost, rejected,
-- processing); `latest_status` adds the transport milestones (confirmed,
-- collected, delivered, completed). shipment_status reads latest_status first and
-- falls back to status:
--   delivered   delivered or completed
--   in_transit  collected
--   cancelled   withdrawn, declined, lost or rejected
--   open        everything else (new, requested, quoted, saved, booked,
--               processing, confirmed)
-- A status Cargoson adds later lands in open; check shipment_status = 'open'
-- against your oldest bookings now and then.
--
-- FREIGHT PRICE is the price of the offer the booking was made on: what was
-- agreed when booking, not the carrier's final invoice. Cancelled shipments keep
-- their price in freight_price but contribute nothing to freight_cost, which is
-- the column to sum.
--
-- Goods lines are aggregated to the booking BEFORE the join, so a booking with
-- six pallet lines still contributes its freight price once.

WITH rows_per_booking AS (
    SELECT
        cargoson_account,
        booking_reference,
        COUNT(*)        AS goods_lines,
        SUM(quantity)   AS packages,
        SUM(weight)     AS total_weight,
        SUM(cbm)        AS total_cbm,
        SUM(ldm)        AS total_ldm
    FROM {{ ref('stg_cargoson__booking_row') }}
    GROUP BY 1, 2
),

classified AS (
    SELECT
        b.*,
        CASE
            WHEN COALESCE(b.latest_status, b.status) IN ('delivered', 'completed') THEN 'delivered'
            WHEN COALESCE(b.latest_status, b.status) = 'collected' THEN 'in_transit'
            WHEN COALESCE(b.latest_status, b.status) IN ('withdrawn', 'declined', 'lost', 'rejected') THEN 'cancelled'
            ELSE 'open'
        END AS shipment_status,
        -- The day a shipment counts on: when the goods were (or are planned to be)
        -- collected, falling back to when the booking was made.
        COALESCE(DATE(b.collected_at), b.collection_date, DATE(b.created_at)) AS shipment_date
    FROM {{ ref('stg_cargoson__booking') }} b
)

SELECT
    c.cargoson_account,
    c.booking_reference,
    c.booking_id,
    c.customer_reference,
    c.tracking_reference,
    c.shipment_date,
    c.shipment_status,
    c.shipment_status = 'cancelled' AS is_cancelled,
    c.shipment_status = 'delivered' AS is_delivered,
    c.status,
    c.latest_status,

    COALESCE(c.carrier_id, c.offer_carrier_id)     AS carrier_id,
    COALESCE(c.carrier_name, c.offer_carrier_name) AS carrier_name,
    c.service_id,
    c.service_name,
    c.freight_type,

    c.collection_country,
    c.collection_city,
    c.delivery_country,
    c.delivery_city,
    CONCAT(COALESCE(c.collection_country, '?'), ' → ', COALESCE(c.delivery_country, '?')) AS lane,
    c.collection_country IS DISTINCT FROM c.delivery_country AS is_international,
    c.delivery_to_private_person,
    c.is_dangerous_goods,
    c.is_temperature_controlled,
    c.incoterm_code,

    c.freight_price,
    c.freight_currency,
    CASE WHEN c.shipment_status <> 'cancelled' THEN c.freight_price END AS freight_cost,
    c.price_source,
    c.goods_value,
    c.goods_value_currency,
    c.co2e_kg,
    c.distance_road,

    COALESCE(r.goods_lines, 0) AS goods_lines,
    r.packages,
    c.measurement_units,
    -- Weight in kg only where the booking is metric. Cargoson does not document
    -- the units of an imperial booking, so its weight is left out rather than
    -- guessed; total_weight_as_entered keeps the raw figure.
    r.total_weight AS total_weight_as_entered,
    CASE WHEN COALESCE(c.measurement_units, 'metric') = 'metric' THEN r.total_weight END AS weight_kg,
    r.total_cbm,
    r.total_ldm,
    SAFE_DIVIDE(
        CASE WHEN c.shipment_status <> 'cancelled' THEN c.freight_price END,
        CASE WHEN COALESCE(c.measurement_units, 'metric') = 'metric' THEN r.total_weight END
    ) AS freight_cost_per_kg,

    c.collection_date,
    c.estimated_collection_date,
    c.estimated_delivery_date,
    c.requested_delivery_date,
    c.quoted_transit_time,
    c.created_at,
    c.confirmed_at,
    c.collected_at,
    c.delivered_at,
    c.completed_at,

    -- Actual door-to-door days, collection to delivery, in calendar days.
    DATE_DIFF(DATE(c.delivered_at), DATE(c.collected_at), DAY) AS transit_days,
    -- On time against the carrier's own estimate on the offer. NULL, not FALSE,
    -- when either date is missing: an unknown is not a late delivery, and on-time
    -- rates downstream divide by the shipments where this is not NULL.
    CASE
        WHEN c.delivered_at IS NULL OR c.estimated_delivery_date IS NULL THEN NULL
        ELSE DATE(c.delivered_at) <= c.estimated_delivery_date
    END AS is_on_time
FROM classified c
LEFT JOIN rows_per_booking r
    ON  r.cargoson_account  = c.cargoson_account
    AND r.booking_reference = c.booking_reference
