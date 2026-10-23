-- One row per booking, per Cargoson connection.
--
-- Bookings are stored one row per reference, so a duplicate means a second
-- connection was unioned into staging without changing the cargoson_account
-- label, or the goods-line aggregation in core.cargoson.shipments stopped being
-- one row per booking. Either one doubles freight spend downstream.

SELECT
    cargoson_account,
    booking_reference,
    COUNT(*) AS rows_for_booking
FROM {{ ref('core_cargoson__shipments') }}
GROUP BY 1, 2
HAVING COUNT(*) > 1
