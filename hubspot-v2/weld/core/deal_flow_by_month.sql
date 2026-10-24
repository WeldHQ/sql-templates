-- core.hubspot_v2.deal_flow_by_month
-- Deals created, won and lost per month, per pipeline and owner, with win rate.
-- Grain: month x pipeline x owner. Money: the portal's home currency.
-- Depends on: core.hubspot_v2.deal_pipeline
--
-- Recreates HubSpot's "Deals created" and "Deals won/lost" reports by month.
--
-- WHICH DATE EACH EVENT LANDS ON:
--   created     -> created_date.
--   won / lost  -> close_date. HubSpot sets the close date to the day a deal moves
--                  into a closed stage, so for closed deals this is the real close
--                  day. A portal can turn that automation off in its pipeline
--                  settings; if yours has, close_date is whatever the rep typed.
--   forecast    -> close_date of open deals: what reps expect to close that month.
--
-- Built on a month spine, so an owner with a quiet month returns a row of zeros
-- rather than vanishing and letting a line chart draw straight over the gap.

WITH month_spine AS (
    SELECT month
    FROM UNNEST(GENERATE_DATE_ARRAY(
        (SELECT DATE_TRUNC(MIN(created_date), MONTH) FROM {{core.hubspot_v2.deal_pipeline}}),
        -- A year ahead, because open deals forecast into the future.
        DATE_TRUNC(DATE_ADD(CURRENT_DATE(), INTERVAL 1 YEAR), MONTH),
        INTERVAL 1 MONTH
    )) AS month
),

-- Owners and pipelines that actually carry deals. owner_id is coalesced to a
-- placeholder so unassigned deals keep a row of their own instead of dropping out of
-- the equality joins below.
keys AS (
    SELECT DISTINCT
        hubspot_portal,
        pipeline_id,
        pipeline_label,
        COALESCE(owner_id, 'unassigned') AS owner_key,
        owner_id,
        owner_name
    FROM {{core.hubspot_v2.deal_pipeline}}
),

created AS (
    SELECT
        DATE_TRUNC(created_date, MONTH) AS month,
        hubspot_portal,
        pipeline_id,
        COALESCE(owner_id, 'unassigned') AS owner_key,
        COUNT(*)                         AS deals_created,
        SUM(amount_home_currency)        AS deals_created_amount
    FROM {{core.hubspot_v2.deal_pipeline}}
    WHERE created_date IS NOT NULL
    GROUP BY 1, 2, 3, 4
),

closed AS (
    SELECT
        DATE_TRUNC(close_date, MONTH)    AS month,
        hubspot_portal,
        pipeline_id,
        COALESCE(owner_id, 'unassigned') AS owner_key,
        COUNTIF(is_won)                  AS deals_won,
        SUM(won_amount)                  AS deals_won_amount,
        COUNTIF(is_lost)                 AS deals_lost,
        SUM(lost_amount)                 AS deals_lost_amount,
        COUNTIF(is_open)                 AS deals_forecast,
        SUM(open_amount)                 AS forecast_amount,
        SUM(weighted_open_amount)        AS weighted_forecast_amount,
        -- Summed, not averaged, so the cycle length below is a true mean over
        -- won deals rather than a mean of monthly means.
        SUM(CASE WHEN is_won THEN age_days END) AS won_age_days_total
    FROM {{core.hubspot_v2.deal_pipeline}}
    WHERE close_date IS NOT NULL
    GROUP BY 1, 2, 3, 4
)

SELECT
    s.month,
    k.hubspot_portal,
    k.pipeline_id,
    k.pipeline_label,
    k.owner_id,
    k.owner_name,

    COALESCE(c.deals_created, 0)            AS deals_created,
    COALESCE(c.deals_created_amount, 0)     AS deals_created_amount,
    COALESCE(x.deals_won, 0)                AS deals_won,
    COALESCE(x.deals_won_amount, 0)         AS deals_won_amount,
    COALESCE(x.deals_lost, 0)               AS deals_lost,
    COALESCE(x.deals_lost_amount, 0)        AS deals_lost_amount,
    COALESCE(x.deals_forecast, 0)           AS deals_forecast,
    COALESCE(x.forecast_amount, 0)          AS forecast_amount,
    COALESCE(x.weighted_forecast_amount, 0) AS weighted_forecast_amount,

    -- Win rate over decided deals only. Counting open deals as not-yet-won would
    -- drag every recent month down. To roll up over several months or owners,
    -- sum deals_won and deals_lost first and divide once: averaging this column
    -- gives every month the same weight regardless of volume.
    SAFE_DIVIDE(x.deals_won, x.deals_won + x.deals_lost)                 AS win_rate,
    SAFE_DIVIDE(x.deals_won_amount, x.deals_won_amount + x.deals_lost_amount) AS win_rate_by_value,
    SAFE_DIVIDE(x.deals_won_amount, x.deals_won)                         AS average_won_deal_size,
    SAFE_DIVIDE(x.won_age_days_total, x.deals_won)                       AS average_days_to_win
FROM month_spine s
CROSS JOIN keys k
LEFT JOIN created c
       ON c.month          = s.month
      AND c.hubspot_portal = k.hubspot_portal
      AND c.pipeline_id    = k.pipeline_id
      AND c.owner_key      = k.owner_key
LEFT JOIN closed x
       ON x.month          = s.month
      AND x.hubspot_portal = k.hubspot_portal
      AND x.pipeline_id    = k.pipeline_id
      AND x.owner_key      = k.owner_key
