-- staging.cargoson.booking_row
-- Thin wrapper over raw `booking_rows`. One row per goods line on a booking:
-- "2 EUR pallets, 300 kg". A booking has one or more.
--
-- UNITS. Cargoson documents weight as the TOTAL weight of the line (5 pallets of
-- 100 kg is 500, not 100), cbm as the line's volume in cubic metres and ldm as
-- loading metres. Those are the metric units; a booking made with
-- measurement_units = 'imperial' is flagged in core and its weight is not
-- converted, because Cargoson does not document the imperial units.
--
-- Joins to staging.cargoson.booking on cargoson_account and booking_reference.
-- Aggregate to the booking before joining, or every booking-level amount is
-- multiplied by its number of lines.

SELECT
    'account_1'                                          AS cargoson_account,
    CAST(booking_reference AS STRING)                    AS booking_reference,
    CAST(quantity AS INT64)                              AS quantity,
    UPPER(NULLIF(TRIM(CAST(package_type AS STRING)), '')) AS package_type,
    CAST(weight AS FLOAT64)                              AS weight,
    CAST(cbm AS FLOAT64)                                 AS cbm,
    CAST(ldm AS FLOAT64)                                 AS ldm,
    NULLIF(TRIM(CAST(description AS STRING)), '')        AS description
FROM {{raw.cargoson.booking_rows}}
