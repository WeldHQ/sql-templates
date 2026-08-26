-- zoho_crm_deal_flow_by_month - deals created, won and lost per month per rep.
-- Grain: month x owner. Currency: org reporting currency.
-- Depends on: core_zoho_crm__deal_pipeline
--
-- Built on a month spine so a rep with no activity in a month still returns a row
-- of zeros rather than disappearing from the series - otherwise a BI line chart
-- interpolates straight over the quiet month and the gap is invisible.
--
-- WHICH DATE EACH EVENT LANDS ON:
--   created  -> created_time, which is a real audit timestamp.
--   won/lost -> closing_date, which is Zoho's EXPECTED close date.
--
-- That second one is the compromise this model cannot avoid. The connector syncs
-- no actual close timestamp and no stage history, so closing_date is the only
-- close date available. If a rep sets a deal to Closed Won in June while its
-- closing_date still says March, this model books the win in March. modified_time
-- would move it to June, but modified_time changes on ANY edit, so a note added in
-- August would move the win again. A forecast date that is wrong once beats a date
-- that moves every time somebody touches the record.
--
-- The fix is upstream, not here: materialise deal_pipeline daily and derive real
-- close dates from when stage_status first changed.

WITH month_spine AS (
    SELECT month
    FROM UNNEST(GENERATE_DATE_ARRAY(
        -- Start the spine at the first deal rather than a hardcoded date, so the
        -- series never carries years of empty leading months.
        (SELECT DATE_TRUNC(MIN(created_date), MONTH) FROM {{ ref('core_zoho_crm__deal_pipeline') }}),
        -- End a year out: closing_date is a forecast, so pipeline legitimately
        -- sits in the future and must not be truncated away.
        DATE_TRUNC(DATE_ADD(CURRENT_DATE(), INTERVAL 1 YEAR), MONTH),
        INTERVAL 1 MONTH
    )) AS month
),

owners AS (
    -- Only reps who actually appear on a deal. Spining every Zoho user against
    -- every month would pad the output with support and admin logins.
    SELECT DISTINCT zoho_org, owner_id, owner_name
    FROM {{ ref('core_zoho_crm__deal_pipeline') }}
),

grid AS (
    SELECT s.month, o.zoho_org, o.owner_id, o.owner_name
    FROM month_spine s
    CROSS JOIN owners o
),

created AS (
    SELECT
        DATE_TRUNC(created_date, MONTH) AS month,
        zoho_org,
        owner_id,
        COUNT(*)          AS deals_created,
        SUM(amount)       AS deals_created_amount
    FROM {{ ref('core_zoho_crm__deal_pipeline') }}
    GROUP BY 1, 2, 3
),

closed AS (
    SELECT
        DATE_TRUNC(closing_date, MONTH) AS month,
        zoho_org,
        owner_id,
        COUNTIF(is_won)                                  AS deals_won,
        SUM(won_amount)                                  AS deals_won_amount,
        COUNTIF(is_lost)                                 AS deals_lost,
        SUM(lost_amount)                                 AS deals_lost_amount,
        -- Open deals forecast to close in this month. Not an outcome - a promise.
        COUNTIF(is_open)                                 AS deals_forecast,
        SUM(pipeline_amount)                             AS pipeline_amount
    FROM {{ ref('core_zoho_crm__deal_pipeline') }}
    WHERE closing_date IS NOT NULL
    GROUP BY 1, 2, 3
)

SELECT
    g.month,
    g.zoho_org,
    g.owner_id,
    g.owner_name,

    COALESCE(c.deals_created, 0)          AS deals_created,
    COALESCE(c.deals_created_amount, 0)   AS deals_created_amount,

    COALESCE(x.deals_won, 0)              AS deals_won,
    COALESCE(x.deals_won_amount, 0)       AS deals_won_amount,
    COALESCE(x.deals_lost, 0)             AS deals_lost,
    COALESCE(x.deals_lost_amount, 0)      AS deals_lost_amount,

    COALESCE(x.deals_forecast, 0)         AS deals_forecast,
    COALESCE(x.pipeline_amount, 0)        AS pipeline_amount,

    -- Win rate by count, over decided deals only. Open deals are excluded from the
    -- denominator: counting them as not-yet-won drags every current month down and
    -- makes the trend look like a collapse.
    SAFE_DIVIDE(
        COALESCE(x.deals_won, 0),
        COALESCE(x.deals_won, 0) + COALESCE(x.deals_lost, 0)
    ) AS win_rate,
    SAFE_DIVIDE(
        COALESCE(x.deals_won_amount, 0),
        COALESCE(x.deals_won_amount, 0) + COALESCE(x.deals_lost_amount, 0)
    ) AS win_rate_by_value,
    -- Average won deal size, the other half of any quota conversation.
    SAFE_DIVIDE(COALESCE(x.deals_won_amount, 0), NULLIF(x.deals_won, 0)) AS average_won_deal_size
FROM grid g
LEFT JOIN created c
       ON c.month    = g.month
      AND c.zoho_org = g.zoho_org
      AND c.owner_id = g.owner_id
LEFT JOIN closed x
       ON x.month    = g.month
      AND x.zoho_org = g.zoho_org
      AND x.owner_id = g.owner_id
ORDER BY g.month, g.owner_name
