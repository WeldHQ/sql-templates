-- stg_seven_rooms__reservation
-- Thin wrapper over raw `reservation`. One row per reservation, latest version,
-- deleted reservations removed.
--
-- `outcome` folds SevenRooms' many statuses into three: canceled, no_show and
-- booked (everything else, from confirmed to seated to left). It reads both
-- `status` and `status_simple` and normalises case and spacing, so "No Show",
-- "NO_SHOW" and "no-show" land in the same bucket. Check the distinct values in
-- your account; if your venues use custom statuses, extend the CASE here.
--
-- Spend columns are what SevenRooms holds for the reservation: prepayments plus
-- on-site payments, including spend pulled in from a connected POS.

WITH normalised AS (
    SELECT
        *,
        UPPER(REGEXP_REPLACE(CONCAT(COALESCE(status, ''), '|', COALESCE(status_simple, '')), r'[\s-]+', '_')) AS status_key
    FROM {{ source('seven_rooms', 'reservation') }}
)

SELECT
    CAST(id AS STRING)                      AS reservation_id,
    CAST(venue_id AS STRING)                AS venue_id,
    CAST(client_id AS STRING)               AS client_id,
    DATE(CAST(date AS TIMESTAMP))           AS reservation_date,
    CAST(real_datetime_of_slot AS TIMESTAMP) AS slot_at,
    CAST(status AS STRING)                  AS status,
    CAST(status_simple AS STRING)           AS status_simple,
    CASE
        WHEN status_key LIKE '%CANCEL%'                             THEN 'canceled'
        WHEN status_key LIKE '%NO_SHOW%' OR status_key LIKE '%NOSHOW%' THEN 'no_show'
        ELSE 'booked'
    END                                     AS outcome,
    CAST(shift_category AS STRING)          AS shift_category,
    CAST(venue_seating_area_name AS STRING) AS seating_area,
    CAST(booked_by AS STRING)               AS booked_by,
    CAST(reservation_type AS STRING)        AS reservation_type,
    COALESCE(is_vip, FALSE)                 AS is_vip,
    CAST(max_guests AS INT64)               AS party_size,
    CAST(arrived_guests AS INT64)           AS arrived_guests,
    CAST(duration AS INT64)                 AS duration_minutes,
    COALESCE(CAST(total_net_payment AS FLOAT64), 0)   AS net_spend,
    COALESCE(CAST(total_gross_payment AS FLOAT64), 0) AS gross_spend,
    COALESCE(CAST(prepayment_total AS FLOAT64), 0)    AS prepayment_total,
    CAST(created AS TIMESTAMP)              AS created_at,
    CAST(updated AS TIMESTAMP)              AS updated_at
FROM normalised
WHERE id IS NOT NULL
  AND deleted IS NULL
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY CAST(id AS STRING), CAST(venue_id AS STRING)
    ORDER BY CAST(updated AS TIMESTAMP) DESC, _weld_synced DESC
) = 1
