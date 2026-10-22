-- staging.sona.org_units
-- Thin wrapper over raw `org_units`: locations, services and the levels above
-- them. Casts, renames, keeps the latest row.
-- Grain: one row per org unit.

SELECT * EXCEPT (row_rank)
FROM (
    SELECT
        CAST(id AS STRING)                  AS org_unit_id,
        CAST(name AS STRING)                AS org_unit_name,
        CAST(org_unit_type_name AS STRING)  AS org_unit_type,
        CAST(parent_org_unit_id AS STRING)  AS parent_org_unit_id,
        CAST(timezone AS STRING)            AS timezone,
        CAST(accounting_cost_code AS STRING) AS accounting_cost_code,
        ROW_NUMBER() OVER (PARTITION BY id ORDER BY _weld_synced DESC) AS row_rank
    FROM {{raw.sona.org_units}}
)
WHERE row_rank = 1
