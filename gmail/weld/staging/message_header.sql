-- staging.gmail.message_header
-- Thin wrapper over raw `message_part_header`, keeping only the headers of the message
-- itself (the root MIME part), not those of attachments or alternative bodies.
-- Lower-cases the header name.
--
-- Grain: message_id x header position.
-- The root part is the one with an empty part id; nested parts are numbered "0", "0.1"
-- and so on. Header names repeat (Received, for example), so position is part of the key.

SELECT
    CAST(message_id AS STRING)              AS message_id,
    CAST(index AS INT64)                    AS header_position,
    LOWER(CAST(name AS STRING))             AS header_name,
    CAST(value AS STRING)                   AS header_value
FROM {{raw.gmail.message_part_header}}
WHERE COALESCE(part_id, '') = ''
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY message_id, index
    ORDER BY _weld_synced DESC
) = 1
