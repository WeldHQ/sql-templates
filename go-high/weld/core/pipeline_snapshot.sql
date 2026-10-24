-- core.go_high.pipeline_snapshot
-- The HighLevel Opportunities board as numbers: how many deals and how much value sit in
-- each stage of each pipeline right now, and how long they have been there.
--
-- Grain: one row per location x pipeline x stage x status, as of the last sync.
-- Depends on: staging.go_high.opportunity, .pipeline, .pipeline_stage
--
-- Open deals are the board. Won, lost and abandoned deals stay attached to the stage they
-- were in when they closed, so they are kept as separate rows by `status` rather than
-- mixed into the open value.
-- `avg_days_in_stage` uses the last stage change, so it is the age of the deal in its
-- current stage, measured at sync time.

SELECT
    o.location_id,
    o.pipeline_id,
    p.pipeline_name,
    o.pipeline_stage_id,
    s.stage_name,
    s.stage_position,
    o.status,

    COUNT(*)                                                    AS opportunities,
    SUM(o.monetary_value)                                       AS total_value,
    AVG(o.monetary_value)                                       AS avg_value,
    AVG(TIMESTAMP_DIFF(CURRENT_TIMESTAMP(),
        COALESCE(o.last_stage_change_at, o.created_at), HOUR) / 24) AS avg_days_in_stage,
    COUNTIF(o.assigned_user_id IS NULL)                         AS unassigned
FROM {{staging.go_high.opportunity}} o
LEFT JOIN {{staging.go_high.pipeline}} p        ON p.pipeline_id = o.pipeline_id
LEFT JOIN {{staging.go_high.pipeline_stage}} s  ON s.pipeline_stage_id = o.pipeline_stage_id
GROUP BY 1, 2, 3, 4, 5, 6, 7
