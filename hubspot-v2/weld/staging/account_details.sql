-- staging.hubspot_v2.account_details
-- Thin wrapper over raw `account_details`: the portal's home currency and time zone.
-- Grain: one row per portal.
--
-- HubSpot stores every timestamp in UTC and draws its own reports in the portal's
-- time zone. Core models read `time_zone` from here so a deal created at 23:30 in
-- New York lands on the same day it does in the HubSpot UI, without hardcoding a
-- zone anywhere.
--
-- The stream is a single-row snapshot. If more than one row is present, the most
-- recently synced one wins.

SELECT
    'portal_1'                                   AS hubspot_portal,
    CAST(portal_id AS STRING)                    AS portal_id,
    UPPER(NULLIF(TRIM(company_currency), ''))    AS home_currency,
    -- Falls back to UTC rather than NULL: a NULL zone would turn every DATE() in
    -- core into NULL and empty the time series.
    COALESCE(NULLIF(TRIM(time_zone), ''), 'UTC') AS time_zone,
    account_type,
    ui_domain
FROM {{raw.hubspot_v2.account_details}}
QUALIFY ROW_NUMBER() OVER (ORDER BY _weld_synced DESC) = 1
