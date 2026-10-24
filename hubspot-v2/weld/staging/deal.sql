-- staging.hubspot_v2.deal
-- Thin wrapper over raw `deal`. Casts, renames, drops archived deals.
-- Grain: one row per deal.
--
-- HubSpot ships the outcome as booleans (hs_is_closed, hs_is_closed_won), so unlike
-- most CRMs nothing here has to guess won or lost from a stage name. Those two flags
-- follow the stage's own "closed won / closed lost" setting in the pipeline.
--
-- TYPES. Standard properties land with fixed types, but a portal can change a
-- property's type, and custom properties land as strings. Every cast below is
-- written so it works whether the raw column is the typed value or its string form:
-- CAST(x AS BOOL) accepts 'true'/'false', and owner ids go through INT64 so a
-- double such as 12345.0 and a string '12345' both become '12345'.
--
-- ARCHIVED DEALS are dropped here. The connector syncs deleted (archived) records
-- with archived = true so they can be removed downstream; HubSpot's own reports
-- exclude them.

SELECT
    'portal_1'                                              AS hubspot_portal,
    CAST(deal_id AS STRING)                                 AS deal_id,
    NULLIF(TRIM(properties_dealname), '')                   AS deal_name,
    CAST(properties_pipeline AS STRING)                     AS pipeline_id,
    CAST(properties_dealstage AS STRING)                    AS stage_id,
    NULLIF(TRIM(properties_dealtype), '')                   AS deal_type,

    COALESCE(CAST(properties_hs_is_closed AS BOOL), FALSE)     AS is_closed,
    COALESCE(CAST(properties_hs_is_closed_won AS BOOL), FALSE) AS is_closed_won,
    NULLIF(TRIM(properties_closed_lost_reason), '')         AS closed_lost_reason,
    NULLIF(TRIM(properties_closed_won_reason), '')          AS closed_won_reason,

    -- Amount in the deal's own currency, and HubSpot's conversion of it into the
    -- portal's home currency. Only the second can be summed across deals.
    CAST(properties_amount AS FLOAT64)                      AS amount,
    UPPER(NULLIF(TRIM(properties_deal_currency_code), ''))  AS deal_currency,
    CAST(properties_amount_in_home_currency AS FLOAT64)     AS amount_home_currency,
    -- Stage probability as HubSpot stores it, 0 to 1.
    CAST(properties_hs_deal_stage_probability AS FLOAT64)   AS stage_probability,
    NULLIF(TRIM(properties_hs_manual_forecast_category), '') AS forecast_category,

    CAST(properties_createdate AS TIMESTAMP)                AS created_at,
    -- For a closed deal HubSpot sets this to the day the deal entered the closed
    -- stage (unless the portal turned that automation off). For an open deal it is
    -- the rep's expected close date.
    CAST(properties_closedate AS TIMESTAMP)                 AS close_date_at,
    CAST(properties_hs_lastmodifieddate AS TIMESTAMP)       AS last_modified_at,

    CAST(CAST(properties_hubspot_owner_id AS INT64) AS STRING) AS owner_id,
    NULLIF(TRIM(CAST(properties_hubspot_team_id AS STRING)), '') AS team_id,

    -- Activity roll-ups HubSpot maintains on the deal itself. num_notes is
    -- HubSpot's "Number of Sales Activities"; num_contacted_notes is "Number of
    -- times contacted", which only counts touches that reach the buyer (calls,
    -- sales emails, meetings and the like), so it is the smaller of the two.
    CAST(properties_num_notes AS INT64)                     AS num_activities,
    CAST(properties_num_contacted_notes AS INT64)           AS num_times_contacted,
    CAST(properties_notes_last_updated AS TIMESTAMP)        AS last_activity_at,
    CAST(properties_notes_next_activity_date AS TIMESTAMP)  AS next_activity_at,
    CAST(properties_num_associated_contacts AS INT64)       AS num_contacts,

    NULLIF(TRIM(properties_hs_analytics_source), '')        AS original_source
FROM {{raw.hubspot_v2.deal}}
WHERE NOT COALESCE(archived, FALSE)
