-- staging.sprout_social.group
-- Thin wrapper over raw `group`, the Sprout Social groups profiles and cases belong to.
-- Casts, renames, keeps the latest row per group.
-- Grain: one row per group.

SELECT * EXCEPT (row_rank)
FROM (
    SELECT
        CAST(group_id AS STRING)    AS group_id,
        CAST(customer_id AS STRING) AS customer_id,
        CAST(name AS STRING)        AS group_name,
        ROW_NUMBER() OVER (PARTITION BY group_id ORDER BY _weld_synced DESC) AS row_rank
    FROM {{raw.sprout_social.group}}
)
WHERE row_rank = 1
