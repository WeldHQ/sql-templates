-- stg_gong__call_interaction
-- Thin wrapper over raw `call_interaction`: Gong's interaction statistics for a
-- call, one row per statistic, from `interaction.interactionStats`.
--
-- Gong names the statistics in display form ('Talk Ratio', 'Longest Monologue',
-- 'Longest Customer Story', 'Interactivity', 'Patience', 'Question Rate').
-- stat_key normalises that to snake_case so core can pivot on a stable key.
-- `value` is passed through unconverted: Gong's API reference does not state the
-- unit of each statistic publicly, so check one call against the Gong UI before
-- presenting these as percentages or seconds (see the README).
--
-- Deduped on (call_id, name).
--
-- Single Gong instance; see staging.gong.call.

SELECT
    'account_1'                                                     AS gong_account,
    CAST(call_id AS STRING)                                         AS call_id,
    CAST(name AS STRING)                                            AS stat_name,
    TRIM(LOWER(REGEXP_REPLACE(TRIM(CAST(name AS STRING)), r'[^A-Za-z0-9]+', '_')), '_')
                                                                    AS stat_key,
    CAST(value AS FLOAT64)                                          AS stat_value
FROM {{ source('gong', 'call_interaction') }}
WHERE call_id IS NOT NULL
  AND name IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY call_id, name ORDER BY _weld_synced DESC) = 1
