-- core_hubspot_v2__deal_activity
-- Activities logged against each deal: counts by type, connected calls,
-- completed meetings, and the first and latest activity.
-- Grain: one row per deal with at least one logged activity. Join to
-- core.hubspot_v2.deal_pipeline on (hubspot_portal, deal_id); a deal with no
-- row here has nothing logged against it.
-- Depends on: staging.hubspot_v2.engagement_deal, .engagement, .deal
--
-- ATTRIBUTION. An activity counts on every deal its association list names, so
-- a call logged against two deals counts on both. The columns are right per
-- deal and too high when summed over deals. For activity totals use
-- rep_activity, which counts each activity once.
--
-- Only activities that have already happened count towards
-- last_logged_activity_at, so a meeting booked for next week does not make a
-- deal look freshly worked.
--
-- Deleted (archived) deals are dropped, so this covers the same deals as
-- deal_pipeline. This model needs the engagement stream; deal_pipeline does not.

WITH linked AS (
    SELECT
        ed.hubspot_portal,
        ed.deal_id,
        ed.engagement_id,
        e.engagement_type,
        e.status,
        e.meeting_outcome,
        e.occurred_at
    FROM {{ ref('stg_hubspot_v2__engagement_deal') }} ed
    JOIN {{ ref('stg_hubspot_v2__engagement') }} e
      ON e.hubspot_portal = ed.hubspot_portal
     AND e.engagement_id  = ed.engagement_id
    -- Only deals that still exist.
    JOIN {{ ref('stg_hubspot_v2__deal') }} d
      ON d.hubspot_portal = ed.hubspot_portal
     AND d.deal_id        = ed.deal_id
)

SELECT
    hubspot_portal,
    deal_id,
    COUNT(*)                                                         AS logged_activities,
    COUNTIF(engagement_type IN ('EMAIL', 'INCOMING_EMAIL', 'FORWARDED_EMAIL')) AS logged_emails,
    COUNTIF(engagement_type = 'CALL')                                AS logged_calls,
    COUNTIF(engagement_type = 'CALL' AND status = 'COMPLETED')       AS logged_connected_calls,
    COUNTIF(engagement_type = 'MEETING')                             AS logged_meetings,
    COUNTIF(engagement_type = 'MEETING' AND meeting_outcome = 'COMPLETED') AS logged_meetings_completed,
    COUNTIF(engagement_type = 'NOTE')                                AS logged_notes,
    COUNTIF(engagement_type = 'TASK')                                AS logged_tasks,
    MIN(occurred_at)                                                 AS first_logged_activity_at,
    MAX(IF(occurred_at <= CURRENT_TIMESTAMP(), occurred_at, NULL))   AS last_logged_activity_at
FROM linked
GROUP BY 1, 2
