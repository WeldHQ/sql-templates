-- staging.esmiley.registration_point
-- Thin wrapper over raw `registration_point`. One row per registration point: the
-- tree of areas, categories and products that waste is registered against (for
-- example Kitchen > Production waste > Bread). Deleted points are kept, because
-- old registrations still point at them.

SELECT
    CAST(id AS INT64)           AS registration_point_id,
    CAST(parent_id AS INT64)    AS parent_id,
    CAST(account_id AS INT64)   AS account_id,
    CAST(name AS STRING)        AS registration_point_name,
    CAST(label AS STRING)       AS label,
    COALESCE(active, FALSE)     AS is_active,
    deleted_at IS NOT NULL      AS is_deleted
FROM {{raw.esmiley.registration_point}}
WHERE id IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY CAST(id AS INT64) ORDER BY _weld_synced DESC) = 1
