-- staging.cargoson.booking
-- Thin wrapper over raw `bookings`. One row per Cargoson booking (shipment):
-- where it goes, who carries it, what was agreed to pay, and its milestones.
--
-- KEY. Bookings are stored one row per `reference`, Cargoson's booking
-- reference, and the rows table points back at it through booking_reference.
-- `id` is carried along but is not the join key.
--
-- PRICE. offer_total_price arrives as a string; it is the price of the offer
-- the booking was made on, in offer_currency. SAFE_CAST, so a malformed value
-- becomes NULL instead of failing the model. It is the agreed price at booking,
-- not the carrier's final invoice: surcharges added later are not in it.
--
-- TWO CARRIER FIELDS. carrier_* is the carrier on the booking; offer_service_
-- carrier_* is the carrier of the offer it was booked on. They normally agree;
-- core coalesces them so a booking with one of the two missing still has a
-- carrier.
--
-- Classification of status into delivered / cancelled / open is business logic
-- and lives in core.cargoson.shipments.

SELECT
    'account_1'                                                        AS cargoson_account,
    CAST(reference AS STRING)                                          AS booking_reference,
    CAST(id AS STRING)                                                 AS booking_id,
    NULLIF(TRIM(CAST(customer_reference AS STRING)), '')               AS customer_reference,
    NULLIF(TRIM(CAST(tracking_reference AS STRING)), '')               AS tracking_reference,
    LOWER(NULLIF(TRIM(CAST(status AS STRING)), ''))                    AS status,
    LOWER(NULLIF(TRIM(CAST(latest_status AS STRING)), ''))             AS latest_status,
    LOWER(NULLIF(TRIM(CAST(channel AS STRING)), ''))                   AS channel,
    LOWER(NULLIF(TRIM(CAST(measurement_units AS STRING)), ''))         AS measurement_units,

    UPPER(NULLIF(TRIM(CAST(collection_country AS STRING)), ''))        AS collection_country,
    NULLIF(TRIM(CAST(collection_city AS STRING)), '')                  AS collection_city,
    NULLIF(TRIM(CAST(collection_postcode AS STRING)), '')              AS collection_postcode,
    UPPER(NULLIF(TRIM(CAST(delivery_country AS STRING)), ''))          AS delivery_country,
    NULLIF(TRIM(CAST(delivery_city AS STRING)), '')                    AS delivery_city,
    NULLIF(TRIM(CAST(delivery_postcode AS STRING)), '')                AS delivery_postcode,
    CAST(delivery_to_private_person AS BOOL)                           AS delivery_to_private_person,
    UPPER(NULLIF(TRIM(CAST(incoterm_code AS STRING)), ''))             AS incoterm_code,
    CAST(adr AS BOOL)                                                  AS is_dangerous_goods,
    CAST(frigo AS BOOL)                                                AS is_temperature_controlled,
    CAST(distance_road AS FLOAT64)                                     AS distance_road,

    -- Declared goods value, in cents at the source.
    ROUND(CAST(goods_value_cents AS NUMERIC) / 100, 2)                 AS goods_value,
    UPPER(NULLIF(TRIM(CAST(goods_value_currency AS STRING)), ''))      AS goods_value_currency,

    SAFE_CAST(NULLIF(TRIM(CAST(offer_total_price AS STRING)), '') AS NUMERIC) AS freight_price,
    UPPER(NULLIF(TRIM(CAST(offer_currency AS STRING)), ''))            AS freight_currency,
    LOWER(NULLIF(TRIM(CAST(offer_source_of_price AS STRING)), ''))     AS price_source,
    CAST(offer_co2e_kg AS FLOAT64)                                     AS co2e_kg,
    NULLIF(TRIM(CAST(offer_transit_time AS STRING)), '')               AS quoted_transit_time,
    CAST(offer_estimated_collection_date AS DATE)                      AS estimated_collection_date,
    CAST(offer_estimated_delivery_date AS DATE)                        AS estimated_delivery_date,

    CAST(offer_service_id AS STRING)                                   AS service_id,
    NULLIF(TRIM(CAST(offer_service_name AS STRING)), '')               AS service_name,
    LOWER(NULLIF(TRIM(CAST(offer_service_freight_type AS STRING)), '')) AS freight_type,
    CAST(offer_service_carrier_id AS STRING)                           AS offer_carrier_id,
    NULLIF(TRIM(CAST(offer_service_carrier_name AS STRING)), '')       AS offer_carrier_name,
    CAST(carrier_id AS STRING)                                         AS carrier_id,
    NULLIF(TRIM(CAST(carrier_name AS STRING)), '')                     AS carrier_name,

    CAST(collection_date AS DATE)                                      AS collection_date,
    CAST(delivery_date AS DATE)                                        AS requested_delivery_date,
    CAST(created_at AS TIMESTAMP)                                      AS created_at,
    CAST(updated_at AS TIMESTAMP)                                      AS updated_at,
    CAST(confirmed_at AS TIMESTAMP)                                    AS confirmed_at,
    CAST(collected_at AS TIMESTAMP)                                    AS collected_at,
    CAST(delivered_at AS TIMESTAMP)                                    AS delivered_at,
    CAST(completed_at AS TIMESTAMP)                                    AS completed_at,
    CAST(archived_at AS TIMESTAMP)                                     AS archived_at
FROM {{raw.cargoson.bookings}}
