-- stg_launchdarkly__feature_flag
-- Thin wrapper over raw `feature_flag`. Casts, renames, converts LaunchDarkly's
-- millisecond timestamps, keeps the latest row per flag.
--
-- Grain: one row per project x flag key. Flag keys are only unique within a project,
-- so project_id is part of every key downstream.
--
-- The full flag list is read on each sync, so archived flags are
-- included (archived = TRUE) and a flag deleted in LaunchDarkly keeps its last row.

SELECT * EXCEPT (row_rank)
FROM (
    SELECT
        CAST(project_id AS STRING)                                  AS project_id,
        CAST(project_key AS STRING)                                 AS project_key,
        CAST(key AS STRING)                                         AS flag_key,
        CAST(name AS STRING)                                        AS flag_name,
        CAST(description AS STRING)                                 AS description,
        LOWER(CAST(kind AS STRING))                                 AS flag_kind,
        CAST(tags AS STRING)                                        AS tags,
        COALESCE(CAST(temporary AS BOOL), FALSE)                    AS is_temporary,
        COALESCE(CAST(archived AS BOOL), FALSE)                     AS is_archived,
        COALESCE(CAST(deprecated AS BOOL), FALSE)                   AS is_deprecated,
        -- LaunchDarkly sends Unix epoch milliseconds.
        TIMESTAMP_MILLIS(CAST(creation_date AS INT64))              AS created_at,
        TIMESTAMP_MILLIS(CAST(deprecated_date AS INT64))            AS deprecated_at,
        CAST(version AS INT64)                                      AS flag_version,
        CAST(maintainer_id AS STRING)                               AS maintainer_id,
        TRIM(CONCAT(COALESCE(CAST(maintainer_first_name AS STRING), ''), ' ',
                    COALESCE(CAST(maintainer_last_name AS STRING), '')))
                                                                    AS maintainer_name,
        CAST(maintainer_email AS STRING)                            AS maintainer_email,
        COALESCE(CAST(client_side_availability_using_mobile_key AS BOOL), FALSE) AS is_available_to_mobile_sdks,
        ROW_NUMBER() OVER (PARTITION BY project_id, key ORDER BY _weld_synced DESC) AS row_rank
    FROM {{ source('launchdarkly', 'feature_flag') }}
)
WHERE row_rank = 1
