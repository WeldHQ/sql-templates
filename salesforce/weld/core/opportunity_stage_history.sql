-- core.salesforce.opportunity_stage_history
-- Every stage each opportunity has been in, when it got there, when it left and
-- how long it stayed. Grain: one row per opportunity x stage entry. An
-- opportunity that returns to a stage it already visited gets a second row.
-- Depends on: staging.salesforce.opportunity_history, .opportunity_stage,
--             core.salesforce.opportunity_pipeline
--
-- HOW IT IS BUILT. OpportunityHistory writes a row whenever stage, amount,
-- probability, close date or forecast category changes. Rows where the stage did
-- not change (an amount edit, say) are dropped, so what remains is one row per
-- stage entry. An entry lasts until the next one; the latest is still running and
-- has exited_at NULL.
--
-- entered_closed_at on the closing entry is when the opportunity actually moved
-- to Closed Won or Closed Lost, which close_date on the opportunity does not
-- reliably tell you.
--
-- moved_backwards compares the Setup sort order of the two stages. Stages that
-- are no longer in the picklist have no sort order and are never called
-- backwards.

WITH changes AS (
    SELECT
        salesforce_org,
        opportunity_id,
        history_id,
        stage_name,
        amount,
        changed_at,
        changed_by_id,
        LAG(stage_name) OVER (
            PARTITION BY salesforce_org, opportunity_id
            ORDER BY changed_at, history_id
        ) AS previous_stage_name
    FROM {{staging.salesforce.opportunity_history}}
    WHERE stage_name IS NOT NULL
),

entries AS (
    SELECT *
    FROM changes
    WHERE previous_stage_name IS NULL
       OR previous_stage_name <> stage_name
),

sequenced AS (
    SELECT
        e.salesforce_org,
        e.opportunity_id,
        e.stage_name,
        e.amount                       AS amount_at_entry,
        e.changed_at                   AS entered_at,
        e.changed_by_id                AS entered_by_id,
        LEAD(e.changed_at) OVER w      AS exited_at,
        LEAD(e.stage_name) OVER w      AS next_stage_name,
        ROW_NUMBER() OVER w            AS entry_number
    FROM entries e
    WINDOW w AS (PARTITION BY e.salesforce_org, e.opportunity_id ORDER BY e.changed_at, e.history_id)
),

stages AS (
    SELECT *
    FROM {{staging.salesforce.opportunity_stage}}
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY salesforce_org, stage_name ORDER BY stage_is_active DESC, stage_id
    ) = 1
)

SELECT
    q.salesforce_org,
    q.opportunity_id,
    p.opportunity_name,
    q.entry_number,
    q.stage_name,
    s.stage_label,
    s.stage_sort_order,
    s.stage_is_closed,
    s.stage_is_won,
    q.next_stage_name,
    q.entered_at,
    q.exited_at,
    q.exited_at IS NULL                                   AS is_current_stage,
    q.entered_by_id,
    q.amount_at_entry,
    -- Hours as well as days, so stages passed through within a day do not round
    -- to zero. For the current stage, time so far.
    TIMESTAMP_DIFF(COALESCE(q.exited_at, CURRENT_TIMESTAMP()), q.entered_at, MINUTE) / 60.0
                                                          AS hours_in_stage,
    TIMESTAMP_DIFF(COALESCE(q.exited_at, CURRENT_TIMESTAMP()), q.entered_at, MINUTE) / 1440.0
                                                          AS days_in_stage,
    COALESCE(ns.stage_sort_order < s.stage_sort_order, FALSE) AS moved_backwards,
    IF(COALESCE(s.stage_is_closed, FALSE), q.entered_at, NULL) AS entered_closed_at,

    p.opportunity_status,
    p.currency_code,
    p.amount                                              AS current_amount,
    p.owner_id,
    p.owner_name
FROM sequenced q
-- INNER: history of an opportunity that has since been deleted is dropped, so
-- this model covers the same opportunities as opportunity_pipeline.
JOIN {{core.salesforce.opportunity_pipeline}} p
  ON p.salesforce_org = q.salesforce_org
 AND p.opportunity_id = q.opportunity_id
LEFT JOIN stages s
       ON s.salesforce_org = q.salesforce_org
      AND s.stage_name     = q.stage_name
LEFT JOIN stages ns
       ON ns.salesforce_org = q.salesforce_org
      AND ns.stage_name     = q.next_stage_name
