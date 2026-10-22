-- Every status the account actually uses is one shipments.sql knows about.
--
-- shipment_status sends anything unrecognised to 'open', which is safe for spend
-- (it is still counted) but wrong for delivery and cancellation rates. This lists
-- each status value that fell through to 'open' without being one of the open
-- statuses Cargoson documents. Add it to the CASE in core.cargoson.shipments.

SELECT
    COALESCE(latest_status, status) AS unclassified_status,
    COUNT(*)                        AS bookings
FROM {{ ref('core_cargoson__shipments') }}
WHERE shipment_status = 'open'
  AND COALESCE(latest_status, status) IS NOT NULL
  AND COALESCE(latest_status, status) NOT IN
      ('new', 'requested', 'quoted', 'saved', 'booked', 'processing', 'confirmed')
GROUP BY 1
