-- stg_hibob__entity_name
-- Thin wrapper over raw `entity_names`: HiBob's named lists (departments, sites,
-- titles and your own lists), one row per list item including archived ones.

SELECT
    LOWER(CAST(entity_type AS STRING))  AS list_name,
    CAST(id AS STRING)                  AS item_id,
    CAST(name AS STRING)                AS item_name,
    CAST(value AS STRING)               AS item_value,
    COALESCE(archived, FALSE)           AS is_archived
FROM {{ source('hibob', 'entity_names') }}
WHERE id IS NOT NULL
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY LOWER(CAST(entity_type AS STRING)), CAST(id AS STRING)
    ORDER BY _weld_synced DESC
) = 1
