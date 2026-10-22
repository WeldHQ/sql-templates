-- stg_monday__item
-- Thin wrapper over raw `item`. One row per item or subitem.
--
-- Only items monday returns from a board's items page are synced: archived and
-- deleted items are not in this table. `account_id` exists on the raw table but
-- the connector does not request it, so it is not used.

SELECT
    CAST(id AS STRING)              AS item_id,
    CAST(board_id AS STRING)        AS board_id,
    CAST(parent_item_id AS STRING)  AS parent_item_id,
    parent_item_id IS NOT NULL      AS is_subitem,
    CAST(name AS STRING)            AS item_name,
    CAST(creator_id AS STRING)      AS creator_id,
    CAST(created_at AS TIMESTAMP)   AS created_at,
    CAST(updated_at AS TIMESTAMP)   AS updated_at,
    CAST(relative_link AS STRING)   AS relative_link
FROM {{ source('monday', 'item') }}
