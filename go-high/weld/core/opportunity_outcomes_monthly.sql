-- core.go_high.opportunity_outcomes_monthly
-- Win rate and won value by the month deals were created, per pipeline and lead source:
-- the cohort view behind HighLevel's opportunity and lead source reports.
--
-- Grain: one row per month created x location x pipeline x source.
-- Depends on: staging.go_high.opportunity, .pipeline
--
-- Cohorted on created month, so a deal created in March and won in May counts as a March
-- win. That answers "how well did March's leads convert", and recent months keep
-- improving as their open deals close.
-- `win_rate` is won over closed (won + lost); abandoned deals are excluded from it and
-- counted separately. `days_to_win` uses the last status change as the close time.

SELECT
    DATE_TRUNC(DATE(o.created_at), MONTH)                       AS created_month,
    o.location_id,
    o.pipeline_id,
    p.pipeline_name,
    COALESCE(o.source, '(none)')                                AS source,

    COUNT(*)                                                    AS opportunities,
    COUNTIF(o.status = 'open')                                  AS open,
    COUNTIF(o.status = 'won')                                   AS won,
    COUNTIF(o.status = 'lost')                                  AS lost,
    COUNTIF(o.status = 'abandoned')                             AS abandoned,
    SAFE_DIVIDE(COUNTIF(o.status = 'won'),
                COUNTIF(o.status IN ('won', 'lost')))           AS win_rate,

    SUM(o.monetary_value)                                       AS total_value,
    SUM(IF(o.status = 'won', o.monetary_value, 0))              AS won_value,
    SUM(IF(o.status = 'open', o.monetary_value, 0))             AS open_value,
    AVG(IF(o.status = 'won',
        TIMESTAMP_DIFF(o.last_status_change_at, o.created_at, HOUR) / 24, NULL)) AS avg_days_to_win
FROM {{staging.go_high.opportunity}} o
LEFT JOIN {{staging.go_high.pipeline}} p ON p.pipeline_id = o.pipeline_id
WHERE o.created_at IS NOT NULL
GROUP BY 1, 2, 3, 4, 5
