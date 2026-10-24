-- staging.seven_rooms.venue
-- Thin wrapper over raw `venue`. One row per venue.

SELECT
    CAST(id AS STRING)               AS venue_id,
    CAST(name AS STRING)             AS venue_name,
    CAST(venue_group_name AS STRING) AS venue_group_name,
    UPPER(CAST(currency_code AS STRING)) AS currency,
    CAST(timezone AS STRING)         AS timezone
FROM {{raw.seven_rooms.venue}}
WHERE id IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY CAST(id AS STRING) ORDER BY _weld_synced DESC) = 1
