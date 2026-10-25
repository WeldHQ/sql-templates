-- core_salesforce__pipeline_flow_daily
-- Opportunities created, won and lost, and open pipeline due, per day per owner.
-- Grain: date_day x salesforce_org x owner_id x currency_code.
-- Depends on: core.salesforce.opportunity_pipeline
--
-- WHICH DATE EACH COUNT LANDS ON:
--   created         -> created_date, a system timestamp (UTC day).
--   won / lost      -> close_date. Salesforce does not set it on close, so it is
--                      the date the rep left in the field. Most orgs require it to
--                      be today or earlier on close; check yours.
--   open, due       -> close_date of open opportunities: the expected close date.
--
-- ROLLING UP. Every ratio here has its parts alongside it. For a month, a team or
-- a quarter, sum the parts and divide once: win_rate is opportunities_won /
-- (opportunities_won + opportunities_lost), average_sales_cycle_days is
-- won_cycle_days / opportunities_won. Averaging the daily ratios weights a quiet
-- day the same as a busy one.
--
-- Built on a spine, so an owner with a quiet day returns zeros instead of a gap.
-- The spine stops two years ahead: open opportunities expected to close later
-- than that are left out of open_amount_due (they stay in opportunity_pipeline).

WITH bounds AS (
    SELECT
        -- A close date can be backdated before any creation date.
        LEAST(MIN(created_date), COALESCE(MIN(close_date), MIN(created_date))) AS first_day,
        LEAST(
            GREATEST(MAX(close_date), CURRENT_DATE()),
            DATE_ADD(CURRENT_DATE(), INTERVAL 2 YEAR)
        )                                                        AS last_day
    FROM {{ ref('core_salesforce__opportunity_pipeline') }}
),

day_spine AS (
    SELECT date_day
    FROM bounds, UNNEST(GENERATE_DATE_ARRAY(first_day, last_day)) AS date_day
),

owners AS (
    -- Only people who own at least one opportunity, so admin and integration
    -- users do not pad the series.
    SELECT DISTINCT salesforce_org, owner_id, currency_code
    FROM {{ ref('core_salesforce__opportunity_pipeline') }}
),

created AS (
    SELECT
        created_date                     AS date_day,
        salesforce_org,
        owner_id,
        currency_code,
        COUNT(*)                         AS opportunities_created,
        SUM(amount)                      AS created_amount
    FROM {{ ref('core_salesforce__opportunity_pipeline') }}
    GROUP BY 1, 2, 3, 4
),

closing AS (
    SELECT
        close_date                       AS date_day,
        salesforce_org,
        owner_id,
        currency_code,
        COUNTIF(is_won)                  AS opportunities_won,
        SUM(won_amount)                  AS won_amount,
        SUM(IF(is_won, age_days, NULL))  AS won_cycle_days,
        COUNTIF(is_lost)                 AS opportunities_lost,
        SUM(lost_amount)                 AS lost_amount,
        COUNTIF(is_open)                 AS open_opportunities_due,
        SUM(open_amount)                 AS open_amount_due,
        SUM(weighted_open_amount)        AS weighted_open_amount_due
    FROM {{ ref('core_salesforce__opportunity_pipeline') }}
    WHERE close_date IS NOT NULL
    GROUP BY 1, 2, 3, 4
),

flow AS (
    SELECT
        d.date_day,
        o.salesforce_org,
        o.owner_id,
        o.currency_code,
        COALESCE(c.opportunities_created, 0)    AS opportunities_created,
        COALESCE(c.created_amount, 0)           AS created_amount,
        COALESCE(x.opportunities_won, 0)        AS opportunities_won,
        COALESCE(x.won_amount, 0)               AS won_amount,
        COALESCE(x.won_cycle_days, 0)           AS won_cycle_days,
        COALESCE(x.opportunities_lost, 0)       AS opportunities_lost,
        COALESCE(x.lost_amount, 0)              AS lost_amount,
        COALESCE(x.open_opportunities_due, 0)   AS open_opportunities_due,
        COALESCE(x.open_amount_due, 0)          AS open_amount_due,
        COALESCE(x.weighted_open_amount_due, 0) AS weighted_open_amount_due
    FROM day_spine d
    CROSS JOIN owners o
    LEFT JOIN created c
           ON c.date_day       = d.date_day
          AND c.salesforce_org = o.salesforce_org
          AND c.owner_id       = o.owner_id
          AND c.currency_code  = o.currency_code
    LEFT JOIN closing x
           ON x.date_day       = d.date_day
          AND x.salesforce_org = o.salesforce_org
          AND x.owner_id       = o.owner_id
          AND x.currency_code  = o.currency_code
)

SELECT
    f.date_day,
    DATE_TRUNC(f.date_day, MONTH)                         AS month,
    f.salesforce_org,
    f.owner_id,
    u.user_name                                           AS owner_name,
    u.is_active                                           AS owner_is_active,
    f.currency_code,

    f.opportunities_created,
    f.created_amount,
    f.opportunities_won,
    f.won_amount,
    f.opportunities_lost,
    f.lost_amount,
    f.won_cycle_days,
    f.open_opportunities_due,
    f.open_amount_due,
    f.weighted_open_amount_due,

    -- Decided opportunities only: open ones are not in the denominator.
    SAFE_DIVIDE(f.opportunities_won, f.opportunities_won + f.opportunities_lost) AS win_rate,
    SAFE_DIVIDE(f.won_amount, f.won_amount + f.lost_amount)                     AS win_rate_by_amount,
    SAFE_DIVIDE(f.won_amount, f.opportunities_won)                              AS average_won_amount,
    SAFE_DIVIDE(f.won_cycle_days, f.opportunities_won)                          AS average_sales_cycle_days
FROM flow f
LEFT JOIN {{ ref('stg_salesforce__user') }} u
       ON u.salesforce_org = f.salesforce_org
      AND u.user_id        = f.owner_id
