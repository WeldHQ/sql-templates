-- staging.monday.board
-- Thin wrapper over raw `board`. One row per board, including archived and
-- deleted boards (the connector asks for every state).

SELECT
    CAST(id AS STRING)              AS board_id,
    CAST(name AS STRING)            AS board_name,
    LOWER(CAST(state AS STRING))    AS board_state,
    LOWER(CAST(board_kind AS STRING)) AS board_kind,
    CAST(board_folder_id AS STRING) AS board_folder_id,
    CAST(item_terminology AS STRING) AS item_terminology,
    CAST(items_count AS INT64)      AS items_count,
    CAST(updated_at AS TIMESTAMP)   AS updated_at
FROM {{raw.monday.board}}
