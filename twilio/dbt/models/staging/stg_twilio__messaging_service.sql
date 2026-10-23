-- stg_twilio__messaging_service
-- Thin wrapper over raw `messaging_service`: one row per Messaging Service, so reports can
-- show its name instead of its sid. Casts and renames.
--
-- Grain: messaging_service_sid.
-- The stream is re-read in full on every sync. The latest copy per sid is kept anyway, so
-- a service renamed between syncs cannot appear twice.

SELECT
    CAST(sid AS STRING)                                         AS messaging_service_sid,
    CAST(account_sid AS STRING)                                 AS account_sid,
    CAST(friendly_name AS STRING)                               AS messaging_service_name,
    CAST(use_case AS STRING)                                    AS use_case,
    CAST(date_created AS TIMESTAMP)                             AS created_at
FROM {{ source('twilio', 'messaging_service') }}
QUALIFY ROW_NUMBER() OVER (PARTITION BY sid ORDER BY date_updated DESC, _weld_synced DESC) = 1
