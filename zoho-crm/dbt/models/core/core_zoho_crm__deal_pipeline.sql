-- zoho_crm_deal_pipeline - every deal, classified, with its account and owner.
-- Grain: one row per deal. Currency: org reporting currency (see scope note).
-- Depends on: stg_zoho_crm__deal, .account, .user
--
-- This is the deal-grain model the other reports read. Classify once here rather
-- than repeating the stage logic in every downstream query.
--
-- SCOPE: current state, not history. Zoho CRM has no history tables in Weld, and
-- this connector syncs no stage-change audit, so there is no way to ask what the
-- pipeline looked like last Tuesday or how long a deal sat in Negotiation. Every
-- deal shows only where it stands now. If you need stage velocity or a pipeline
-- snapshot over time, materialise this model daily and keep the runs.
--
-- Joins are written with explicit ON rather than USING: both deal and account
-- carry owner_id, so a USING(owner_id) join further down would be ambiguous.

{{ config(materialized='table') }}

WITH deal AS (
    SELECT
        d.*,
        -- Zoho ships no is_won / is_closed boolean, so won and lost have to be
        -- read out of the stage string. Matched on a pattern, not an equality
        -- list, because Zoho's own defaults include "Closed-Lost to Competition"
        -- and most orgs add their own stages on top.
        --
        -- Won is tested first so a stage that somehow contains both words is
        -- counted once. tests/assert_deal_stages_are_classified.sql lists every
        -- stage falling through to Open - read it before trusting the split.
        CASE
            WHEN LOWER(d.stage) LIKE '%won%'  THEN 'Won'
            WHEN LOWER(d.stage) LIKE '%lost%' THEN 'Lost'
            ELSE 'Open'
        END AS stage_status
    FROM {{ ref('stg_zoho_crm__deal') }} d
)

SELECT
    d.zoho_org,
    d.deal_id,
    d.deal_name,
    d.stage,
    d.stage_status,
    d.stage_status = 'Open' AS is_open,
    d.stage_status = 'Won'  AS is_won,
    d.stage_status = 'Lost' AS is_lost,

    d.amount,
    -- Split out so BI can sum a column instead of writing the CASE again. An open
    -- deal contributes to pipeline_amount only; a closed one to won or lost.
    CASE WHEN d.stage_status = 'Open' THEN d.amount END AS pipeline_amount,
    CASE WHEN d.stage_status = 'Won'  THEN d.amount END AS won_amount,
    CASE WHEN d.stage_status = 'Lost' THEN d.amount END AS lost_amount,

    DATE(d.created_time) AS created_date,
    d.closing_date,
    d.created_time,
    d.modified_time,

    -- Age of the deal. For a closed deal this is how long it took; for an open one
    -- how long it has been sitting. closing_date is Zoho's EXPECTED close date and
    -- it is not cleared when a deal closes, so on a won or lost deal it is the
    -- forecast that was in place, not necessarily the day money changed hands.
    DATE_DIFF(
        COALESCE(CASE WHEN d.stage_status <> 'Open' THEN d.closing_date END, CURRENT_DATE()),
        DATE(d.created_time),
        DAY
    ) AS age_days,
    -- Open deals whose expected close date has already passed: the cheapest
    -- pipeline-hygiene number there is, and usually the first thing a sales lead
    -- asks for.
    d.stage_status = 'Open' AND d.closing_date < CURRENT_DATE() AS is_overdue,
    CASE
        WHEN d.stage_status = 'Open'
        THEN DATE_DIFF(d.closing_date, CURRENT_DATE(), DAY)
    END AS days_to_expected_close,

    d.account_id,
    a.account_name,
    a.industry,

    d.owner_id,
    u.full_name AS owner_name,
    u.email     AS owner_email,
    u.role_name AS owner_role,
    -- A deal owned by a deactivated rep is unmanaged pipeline. NULL here means the
    -- owner_id did not resolve at all - see tests/assert_owner_ids_resolve.sql.
    u.is_active AS owner_is_active
FROM deal d
LEFT JOIN {{ ref('stg_zoho_crm__account') }} a
       ON a.zoho_org   = d.zoho_org
      AND a.account_id = d.account_id
-- LEFT, not INNER: an owner who has been deleted from Zoho no longer appears in
-- the user module, and an inner join would silently drop their deals from the
-- pipeline total.
LEFT JOIN {{ ref('stg_zoho_crm__user') }} u
       ON u.zoho_org = d.zoho_org
      AND u.user_id  = d.owner_id
