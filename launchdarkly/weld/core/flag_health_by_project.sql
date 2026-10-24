-- core.launchdarkly.flag_health_by_project
-- Flag debt per project: how many flags are live, how many of those are temporary,
-- how many are overdue for cleanup or have nobody responsible for them.
--
-- Grain: one row per project (current state as of the last sync).
-- Depends on: core.launchdarkly.flag_inventory
--
-- Counts only, so every column sums across projects. Rates are computed from the
-- counts in the same row, never averaged across rows.

SELECT
    project_id,
    ANY_VALUE(project_key)                                          AS project_key,
    ANY_VALUE(project_name)                                         AS project_name,

    COUNT(*)                                                        AS flags_total,
    COUNTIF(NOT is_archived)                                        AS flags_live,
    COUNTIF(lifecycle_status = 'live_temporary')                    AS flags_live_temporary,
    COUNTIF(lifecycle_status = 'live_permanent')                    AS flags_live_permanent,
    COUNTIF(lifecycle_status = 'deprecated')                        AS flags_deprecated,
    COUNTIF(is_archived)                                            AS flags_archived,
    COUNTIF(is_cleanup_candidate)                                   AS flags_cleanup_candidates,
    COUNTIF(NOT is_archived AND has_no_maintainer)                  AS flags_live_without_maintainer,
    COUNTIF(created_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)) AS flags_created_last_30_days,

    ROUND(SAFE_DIVIDE(COUNTIF(is_cleanup_candidate),
                      COUNTIF(lifecycle_status = 'live_temporary')), 4) AS cleanup_candidate_share_of_temporary,
    -- Median age of live flags. Rising month on month means flags are added faster
    -- than they are removed.
    APPROX_QUANTILES(IF(NOT is_archived, age_days, NULL), 2)[OFFSET(1)] AS median_live_flag_age_days
FROM {{core.launchdarkly.flag_inventory}}
GROUP BY project_id
