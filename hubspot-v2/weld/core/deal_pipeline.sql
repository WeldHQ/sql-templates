-- core.hubspot_v2.deal_pipeline
-- Every deal with its pipeline, stage, outcome, owner and primary company.
-- Grain: one row per deal. Money: the portal's home currency (amount_home_currency).
-- Depends on: staging.hubspot_v2.deal, .pipeline, .pipeline_stage, .owner,
--             .deal_association, .company, .account_details, .engagement_deal
--
-- This is the deal-grain model the other reports read. It recreates the numbers
-- behind HubSpot's deal board and "Deal forecast" report: open pipeline, weighted
-- pipeline, closed won and closed lost.
--
-- OUTCOME comes from HubSpot's own hs_is_closed / hs_is_closed_won flags, which
-- follow the closed-won / closed-lost setting of each pipeline stage. No stage names
-- are pattern-matched, so custom stages are classified the way HubSpot classifies
-- them.
--
-- ONE COMPANY PER DEAL. A deal can be associated with several companies. Picking
-- one keeps this model at deal grain and stops a deal's amount being counted once per
-- company in company_360. The primary association (HubSpot's association type 5,
-- deal to company) wins; a deal with no primary company falls back to the lowest
-- associated company id, so the choice is stable between runs.
--
-- ACTIVITY ON THE DEAL comes two ways. num_activities and num_times_contacted
-- are HubSpot's own roll-ups. The logged_* columns count the activities whose
-- association list names this deal, by type, so a call logged against two deals
-- counts on both. Use them per deal; for activity totals use rep_activity, which
-- counts each activity once. Only activities that have already happened count
-- towards last_logged_activity_at, so a meeting booked for next week does not
-- make a deal look freshly worked.
--
-- CURRENT STATE. This is where every deal stands now. For how deals moved through
-- the stages, use core.hubspot_v2.deal_stage_history.

WITH portal AS (
    SELECT hubspot_portal, time_zone, home_currency
    FROM {{staging.hubspot_v2.account_details}}
),

deal_activity AS (
    SELECT
        ed.hubspot_portal,
        ed.deal_id,
        COUNT(*)                                                     AS logged_activities,
        COUNTIF(ed.engagement_type IN ('EMAIL', 'INCOMING_EMAIL', 'FORWARDED_EMAIL')) AS logged_emails,
        COUNTIF(ed.engagement_type = 'CALL')                         AS logged_calls,
        COUNTIF(ed.engagement_type = 'MEETING')                      AS logged_meetings,
        COUNTIF(ed.engagement_type = 'NOTE')                         AS logged_notes,
        COUNTIF(ed.engagement_type = 'TASK')                         AS logged_tasks,
        MIN(ed.occurred_at)                                          AS first_logged_activity_at,
        MAX(IF(ed.occurred_at <= CURRENT_TIMESTAMP(), ed.occurred_at, NULL)) AS last_logged_activity_at
    FROM {{staging.hubspot_v2.engagement_deal}} ed
    GROUP BY 1, 2
),

deal_company AS (
    SELECT
        hubspot_portal,
        deal_id,
        to_id AS company_id
    FROM {{staging.hubspot_v2.deal_association}}
    WHERE to_object_type = 'company'
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY hubspot_portal, deal_id
        ORDER BY
            CASE WHEN association_type_id = '5' AND association_category = 'HUBSPOT_DEFINED' THEN 0 ELSE 1 END,
            SAFE_CAST(to_id AS INT64),
            to_id
    ) = 1
)

SELECT
    d.hubspot_portal,
    d.deal_id,
    d.deal_name,
    d.deal_type,

    d.pipeline_id,
    p.pipeline_label,
    d.stage_id,
    s.stage_label,
    s.stage_display_order,

    CASE
        WHEN d.is_closed_won THEN 'Won'
        WHEN d.is_closed     THEN 'Lost'
        ELSE 'Open'
    END                                     AS deal_status,
    NOT d.is_closed                         AS is_open,
    d.is_closed_won                         AS is_won,
    d.is_closed AND NOT d.is_closed_won     AS is_lost,
    d.closed_lost_reason,
    d.closed_won_reason,

    d.amount,
    d.deal_currency,
    d.amount_home_currency,
    pt.home_currency,
    -- Split so BI can sum a column instead of repeating the CASE.
    CASE WHEN NOT d.is_closed THEN d.amount_home_currency END                  AS open_amount,
    CASE WHEN d.is_closed_won THEN d.amount_home_currency END                  AS won_amount,
    CASE WHEN d.is_closed AND NOT d.is_closed_won THEN d.amount_home_currency END AS lost_amount,
    -- Weighted pipeline: open amount x the stage's win probability, the figure in
    -- HubSpot's "weighted amount" column. The deal's own probability is preferred
    -- because a rep or workflow can override it; the stage default fills the gap.
    COALESCE(d.stage_probability, s.stage_probability)                       AS stage_probability,
    CASE
        WHEN NOT d.is_closed
        THEN d.amount_home_currency * COALESCE(d.stage_probability, s.stage_probability)
    END                                                                      AS weighted_open_amount,
    d.forecast_category,

    d.created_at,
    d.close_date_at,
    -- Dates in the portal's time zone, matching the HubSpot UI.
    DATE(d.created_at, COALESCE(pt.time_zone, 'UTC'))        AS created_date,
    DATE(d.close_date_at, COALESCE(pt.time_zone, 'UTC'))     AS close_date,

    -- Time to close for a closed deal, time in pipeline for an open one.
    DATE_DIFF(
        CASE WHEN d.is_closed THEN DATE(d.close_date_at, COALESCE(pt.time_zone, 'UTC'))
             ELSE CURRENT_DATE(COALESCE(pt.time_zone, 'UTC')) END,
        DATE(d.created_at, COALESCE(pt.time_zone, 'UTC')),
        DAY
    )                                       AS age_days,
    -- Open deals whose expected close date has passed. COALESCE because a NULL close
    -- date would otherwise make the flag NULL rather than FALSE.
    COALESCE(
        NOT d.is_closed AND DATE(d.close_date_at, COALESCE(pt.time_zone, 'UTC')) < CURRENT_DATE(COALESCE(pt.time_zone, 'UTC')),
        FALSE
    )                                       AS is_overdue,
    -- Open deals with nothing scheduled: the other half of pipeline hygiene.
    NOT d.is_closed AND d.next_activity_at IS NULL AS has_no_next_activity,

    d.num_activities,
    d.num_times_contacted,
    d.last_activity_at,
    d.next_activity_at,
    d.num_contacts,
    d.original_source,

    -- Activities associated with the deal (an activity on several deals counts on
    -- each). Zero, not NULL, for a deal nobody has logged anything against.
    COALESCE(da.logged_activities, 0)       AS logged_activities,
    COALESCE(da.logged_emails, 0)           AS logged_emails,
    COALESCE(da.logged_calls, 0)            AS logged_calls,
    COALESCE(da.logged_meetings, 0)         AS logged_meetings,
    COALESCE(da.logged_notes, 0)            AS logged_notes,
    COALESCE(da.logged_tasks, 0)            AS logged_tasks,
    da.first_logged_activity_at,
    da.last_logged_activity_at,

    d.owner_id,
    o.owner_name,
    o.owner_email,
    -- NULL means the owner id did not resolve; FALSE means the owner was
    -- deactivated, which makes the deal unmanaged pipeline.
    o.owner_is_active,
    d.team_id,

    dc.company_id,
    c.company_name,
    c.domain                                AS company_domain,
    c.industry                              AS company_industry
FROM {{staging.hubspot_v2.deal}} d
LEFT JOIN portal pt
       ON pt.hubspot_portal = d.hubspot_portal
LEFT JOIN {{staging.hubspot_v2.pipeline}} p
       ON p.hubspot_portal = d.hubspot_portal
      AND p.pipeline_id    = d.pipeline_id
LEFT JOIN {{staging.hubspot_v2.pipeline_stage}} s
       ON s.hubspot_portal = d.hubspot_portal
      AND s.pipeline_id    = d.pipeline_id
      AND s.stage_id       = d.stage_id
LEFT JOIN {{staging.hubspot_v2.owner}} o
       ON o.hubspot_portal = d.hubspot_portal
      AND o.owner_id       = d.owner_id
LEFT JOIN deal_activity da
       ON da.hubspot_portal = d.hubspot_portal
      AND da.deal_id        = d.deal_id
LEFT JOIN deal_company dc
       ON dc.hubspot_portal = d.hubspot_portal
      AND dc.deal_id        = d.deal_id
LEFT JOIN {{staging.hubspot_v2.company}} c
       ON c.hubspot_portal = dc.hubspot_portal
      AND c.company_id     = dc.company_id
