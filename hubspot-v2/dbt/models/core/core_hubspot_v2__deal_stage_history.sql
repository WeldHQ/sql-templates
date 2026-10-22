-- core_hubspot_v2__deal_stage_history
-- Every stage each deal has been in, when it entered, when it left and how long it
-- stayed. Grain: one row per deal x stage entry (a deal that goes back to a stage
-- it already visited gets a second row).
-- Depends on: staging.hubspot_v2.deal_property_history, .pipeline_stage,
--             core.hubspot_v2.deal_pipeline
--
-- Answers what deal_pipeline cannot: how long deals sit in each stage, which stages
-- they skip, and where they stall. It is the data behind HubSpot's "Deal stage
-- funnel" and "Time spent in deal stage" reports.
--
-- HOW IT IS BUILT. Each change to the `dealstage` property is a row in the
-- property history. A stage entry lasts until the next change; the latest entry is
-- still running and has exited_at NULL. Consecutive rows with the same stage (a
-- re-save that wrote the same value) are collapsed into one entry, so they do not
-- show up as zero-day visits.
--
-- REQUIRES the deal_property_history stream. Without it this model is empty.
-- Deals created before HubSpot started recording history for your portal start
-- at the first change it has.

WITH changes AS (
    SELECT
        hubspot_portal,
        deal_id,
        value      AS stage_id,
        changed_at,
        LAG(value) OVER (
            PARTITION BY hubspot_portal, deal_id ORDER BY changed_at
        )          AS previous_stage_id
    FROM {{ ref('stg_hubspot_v2__deal_property_history') }}
    WHERE property = 'dealstage'
      AND value IS NOT NULL
),

entries AS (
    -- Keep only real moves: the first value, and every value that differs from the
    -- one before it.
    SELECT hubspot_portal, deal_id, stage_id, changed_at AS entered_at
    FROM changes
    WHERE previous_stage_id IS NULL
       OR previous_stage_id <> stage_id
),

sequenced AS (
    SELECT
        e.*,
        LEAD(entered_at) OVER w AS exited_at,
        LEAD(stage_id)   OVER w AS next_stage_id,
        ROW_NUMBER()     OVER w AS entry_number
    FROM entries e
    WINDOW w AS (PARTITION BY hubspot_portal, deal_id ORDER BY entered_at)
)

SELECT
    q.hubspot_portal,
    q.deal_id,
    d.deal_name,
    d.pipeline_id,
    d.pipeline_label,
    q.entry_number,
    q.stage_id,
    s.stage_label,
    s.stage_display_order,
    q.next_stage_id,
    ns.stage_label                                  AS next_stage_label,
    q.entered_at,
    q.exited_at,
    q.exited_at IS NULL                             AS is_current_stage,
    -- Hours rather than days so short stages do not round to zero. For the current
    -- stage, time so far.
    TIMESTAMP_DIFF(COALESCE(q.exited_at, CURRENT_TIMESTAMP()), q.entered_at, MINUTE) / 60.0
                                                    AS hours_in_stage,
    TIMESTAMP_DIFF(COALESCE(q.exited_at, CURRENT_TIMESTAMP()), q.entered_at, MINUTE) / 1440.0
                                                    AS days_in_stage,
    -- Did the deal move backwards? Compares display order within the pipeline.
    COALESCE(ns.stage_display_order < s.stage_display_order, FALSE) AS moved_backwards,

    d.deal_status,
    d.amount_home_currency,
    d.owner_id,
    d.owner_name
FROM sequenced q
-- INNER: history for a deal that has since been deleted or archived is dropped, so
-- this model describes the same set of deals as deal_pipeline.
JOIN {{ ref('core_hubspot_v2__deal_pipeline') }} d
  ON d.hubspot_portal = q.hubspot_portal
 AND d.deal_id        = q.deal_id
-- The stage label is looked up in the deal's CURRENT pipeline. A deal moved between
-- pipelines keeps its earlier stage ids, which then find no label; stage_id is
-- always populated.
LEFT JOIN {{ ref('stg_hubspot_v2__pipeline_stage') }} s
       ON s.hubspot_portal = q.hubspot_portal
      AND s.pipeline_id    = d.pipeline_id
      AND s.stage_id       = q.stage_id
LEFT JOIN {{ ref('stg_hubspot_v2__pipeline_stage') }} ns
       ON ns.hubspot_portal = q.hubspot_portal
      AND ns.pipeline_id    = d.pipeline_id
      AND ns.stage_id       = q.next_stage_id
