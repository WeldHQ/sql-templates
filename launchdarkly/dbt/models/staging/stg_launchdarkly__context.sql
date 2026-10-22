-- stg_launchdarkly__context
-- Thin wrapper over raw `context`: every context (user, device, organization, ...)
-- LaunchDarkly has seen evaluate a flag. Casts, renames, de-duplicates.
--
-- Grain: one row per project x environment x context kind x context key, which is
-- the connector's primary key. The same person seen as both a `user` and a `device`
-- context is two rows, as it is in LaunchDarkly.

SELECT * EXCEPT (row_rank)
FROM (
    SELECT
        CAST(project_id AS STRING)          AS project_id,
        CAST(environment_key AS STRING)     AS environment_key,
        CAST(context_kind AS STRING)        AS context_kind,
        CAST(context_key AS STRING)         AS context_key,
        CAST(last_seen AS TIMESTAMP)        AS last_seen_at,
        CAST(application_id AS STRING)      AS application_id,
        ROW_NUMBER() OVER (
            PARTITION BY project_id, environment_key, context_kind, context_key
            ORDER BY _weld_synced DESC
        ) AS row_rank
    FROM {{ source('launchdarkly', 'context') }}
)
WHERE row_rank = 1
