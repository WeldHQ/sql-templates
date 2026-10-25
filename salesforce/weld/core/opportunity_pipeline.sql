-- core.salesforce.opportunity_pipeline
-- Every opportunity with its outcome, stage, account and owner.
-- Grain: one row per opportunity (salesforce_org x opportunity_id).
-- Depends on: staging.salesforce.opportunity, .opportunity_stage, .account, .user
--
-- OUTCOME comes from Salesforce, not from stage names. is_closed and is_won are
-- set by the stage's Type and Probability settings in Setup, so custom stages are
-- classified the way Salesforce classifies them and there is nothing to maintain.
--
-- CURRENCY. In a single-currency org currency_code is ORG_DEFAULT and every amount
-- is in the org currency. In a multi-currency org (see staging.salesforce.opportunity)
-- amounts are in each opportunity's own currency: group by currency_code before
-- summing. Converting to a corporate currency needs Salesforce's CurrencyType or
-- DatedConversionRate objects and is not done here.
--
-- CLOSE DATE. For an open opportunity close_date is the expected close date. For a
-- closed one it is whatever the rep left in the field: Salesforce does not set it
-- automatically on close. core.salesforce.opportunity_stage_history has the
-- moment the stage actually changed.
--
-- Current state only. For the pipeline as it stood on an earlier date, use the
-- stage history model or materialise this one on a schedule and keep the runs.

WITH stages AS (
    -- One row per stage name, so a stage can never fan an opportunity out.
    SELECT *
    FROM {{staging.salesforce.opportunity_stage}}
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY salesforce_org, stage_name ORDER BY stage_is_active DESC, stage_id
    ) = 1
)

SELECT
    o.salesforce_org,
    o.opportunity_id,
    o.opportunity_name,
    o.opportunity_type,
    o.lead_source,

    o.stage_name,
    s.stage_label,
    s.stage_sort_order,
    o.forecast_category,
    CASE
        WHEN o.is_won    THEN 'Won'
        WHEN o.is_closed THEN 'Lost'
        ELSE 'Open'
    END                                                    AS opportunity_status,
    NOT COALESCE(o.is_closed, FALSE)                       AS is_open,
    COALESCE(o.is_won, FALSE)                              AS is_won,
    COALESCE(o.is_closed AND NOT o.is_won, FALSE)          AS is_lost,

    COALESCE(o.currency_iso_code, 'ORG_DEFAULT')           AS currency_code,
    o.amount,
    -- Split by outcome so BI can sum one column instead of repeating the CASE.
    IF(NOT COALESCE(o.is_closed, FALSE), o.amount, NULL)   AS open_amount,
    IF(COALESCE(o.is_won, FALSE), o.amount, NULL)          AS won_amount,
    IF(COALESCE(o.is_closed AND NOT o.is_won, FALSE), o.amount, NULL) AS lost_amount,
    o.probability_percent,
    -- Weighted pipeline: open amount times the opportunity's own probability,
    -- which defaults to the stage's probability unless a rep overrode it.
    IF(NOT COALESCE(o.is_closed, FALSE), o.expected_revenue, NULL) AS weighted_open_amount,

    o.created_at,
    DATE(o.created_at)                                     AS created_date,
    o.close_date,
    o.last_activity_date,
    o.last_modified_at,

    -- Sales cycle for a closed opportunity (created to close date), age so far for
    -- an open one.
    DATE_DIFF(
        IF(COALESCE(o.is_closed, FALSE), o.close_date, CURRENT_DATE()),
        DATE(o.created_at),
        DAY
    )                                                      AS age_days,
    -- Open and past its expected close date. COALESCE so a missing close date
    -- reads as not overdue rather than NULL.
    COALESCE(NOT o.is_closed AND o.close_date < CURRENT_DATE(), FALSE) AS is_overdue,
    IF(NOT COALESCE(o.is_closed, FALSE),
       DATE_DIFF(CURRENT_DATE(), o.last_activity_date, DAY), NULL) AS days_since_last_activity,

    o.account_id,
    a.account_name,
    a.account_type,
    a.industry,
    a.billing_country,

    o.owner_id,
    u.user_name                                            AS owner_name,
    u.email                                                AS owner_email,
    u.is_active                                            AS owner_is_active
FROM {{staging.salesforce.opportunity}} o
LEFT JOIN stages s
       ON s.salesforce_org = o.salesforce_org
      AND s.stage_name     = o.stage_name
-- LEFT joins throughout: an opportunity with no account, or whose account was
-- deleted, still belongs in the pipeline total.
LEFT JOIN {{staging.salesforce.account}} a
       ON a.salesforce_org = o.salesforce_org
      AND a.account_id     = o.account_id
LEFT JOIN {{staging.salesforce.user}} u
       ON u.salesforce_org = o.salesforce_org
      AND u.user_id        = o.owner_id
