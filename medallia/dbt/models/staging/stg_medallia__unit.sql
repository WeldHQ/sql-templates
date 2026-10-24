-- stg_medallia__unit
-- Thin wrapper over raw `unit`. One row per Medallia unit (a store, branch, hotel or
-- team, depending on how the instance is organised).
--
-- Units are only reachable through feedback, so this table holds the primary units
-- of records that have been synced, not every unit in the instance. A record joins to
-- its unit on `unit_identifier`.

SELECT
    'account_1'                                AS medallia_account,
    CAST(id AS STRING)                         AS unit_id,
    CAST(identifier AS STRING)                 AS unit_identifier,
    NULLIF(TRIM(CAST(name AS STRING)), '')     AS unit_name,
    CAST(city AS STRING)                       AS city,
    CAST(timezone AS STRING)                   AS timezone
FROM {{ source('medallia', 'unit') }}
QUALIFY ROW_NUMBER() OVER (PARTITION BY identifier ORDER BY _weld_synced DESC) = 1
