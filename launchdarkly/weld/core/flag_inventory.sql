-- core.launchdarkly.flag_inventory
-- Every feature flag with its age, lifecycle state and owner: the flag list in
-- LaunchDarkly, with the columns you need to find flags that should be cleaned up.
--
-- Grain: one row per project x flag key (current state as of the last sync).
-- Depends on: staging.launchdarkly.feature_flag, staging.launchdarkly.project
--
-- `is_cleanup_candidate` is a heuristic, not a LaunchDarkly status: a temporary flag,
-- still live, more than 90 days old. LaunchDarkly's own "ready to archive" signal
-- depends on evaluation data that the connector does not sync. Change the threshold
-- to match your team's policy; it lives in one place below.

SELECT
    f.project_id,
    COALESCE(p.project_key, f.project_key)              AS project_key,
    p.project_name,
    f.flag_key,
    f.flag_name,
    f.flag_kind,
    f.tags,

    CASE
        WHEN f.is_archived   THEN 'archived'
        WHEN f.is_deprecated THEN 'deprecated'
        WHEN f.is_temporary  THEN 'live_temporary'
        ELSE 'live_permanent'
    END                                                 AS lifecycle_status,
    f.is_temporary,
    f.is_archived,
    f.is_deprecated,

    f.created_at,
    DATE(f.created_at)                                  AS created_date,
    DATE_DIFF(CURRENT_DATE(), DATE(f.created_at), DAY)  AS age_days,
    CASE
        WHEN DATE_DIFF(CURRENT_DATE(), DATE(f.created_at), DAY) <= 30  THEN '0-30 days'
        WHEN DATE_DIFF(CURRENT_DATE(), DATE(f.created_at), DAY) <= 90  THEN '31-90 days'
        WHEN DATE_DIFF(CURRENT_DATE(), DATE(f.created_at), DAY) <= 365 THEN '91-365 days'
        ELSE 'over 1 year'
    END                                                 AS age_bucket,
    f.deprecated_at,
    f.flag_version,

    f.maintainer_id,
    NULLIF(f.maintainer_name, '')                       AS maintainer_name,
    f.maintainer_email,
    f.maintainer_id IS NULL                             AS has_no_maintainer,

    (
        f.is_temporary
        AND NOT f.is_archived
        AND NOT f.is_deprecated
        AND DATE_DIFF(CURRENT_DATE(), DATE(f.created_at), DAY) > 90
    )                                                   AS is_cleanup_candidate
FROM {{staging.launchdarkly.feature_flag}} f
LEFT JOIN {{staging.launchdarkly.project}} p
  ON p.project_id = f.project_id
