-- stg_hubspot_v2__deal_property_history
-- Thin wrapper over raw `deal_property_history`. Grain: one row per deal x property
-- x change. Only the properties core uses are kept, because the raw table holds the
-- history of every deal property and is by far the largest table in the connector.
--
-- This is the stream that makes stage velocity possible: each time a deal's
-- `dealstage` changed, HubSpot recorded the new value and when.

SELECT DISTINCT
    'portal_1'                          AS hubspot_portal,
    CAST(deal_id AS STRING)             AS deal_id,
    property,
    NULLIF(TRIM(value), '')             AS value,
    CAST(timestamp AS TIMESTAMP)        AS changed_at,
    source_type,
    updated_by_user_id
FROM {{ source('hubspot_v2', 'deal_property_history') }}
WHERE property IN ('dealstage', 'pipeline')
