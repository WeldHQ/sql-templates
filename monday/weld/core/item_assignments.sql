-- core.monday.item_assignments
-- Who is assigned to what: every person in every people column on every item.
-- Grain: item x people column x person. Items with nobody assigned have no row.
--
-- People columns store JSON like {"personsAndTeams":[{"id":123,"kind":"person"}]}.
-- Teams assigned to an item are skipped: only `kind = person` entries are kept, so
-- an item assigned to a team counts for nobody here.
--
-- An item with two people columns (say "Owner" and "Reviewer") produces rows for
-- both. Filter on `column_id` if you want one role only. Column titles are not
-- synced, so the id is what you have.

WITH people AS (
    SELECT
        v.item_id,
        v.column_id,
        JSON_VALUE(p, '$.id')    AS user_id
    FROM {{staging.monday.item_column_value}} v,
    UNNEST(JSON_QUERY_ARRAY(v.value_json, '$.personsAndTeams')) AS p
    WHERE v.column_type IN ('people', 'multiple-person')
      AND JSON_VALUE(p, '$.kind') = 'person'
)

SELECT
    i.item_id,
    i.item_name,
    i.is_subitem,
    i.parent_item_id,
    i.board_id,
    b.board_name,
    b.board_state,
    p.column_id,
    p.user_id,
    u.user_name,
    u.email,
    i.created_at  AS item_created_at,
    i.updated_at  AS item_updated_at,
    DATE_DIFF(CURRENT_DATE(), DATE(i.created_at), DAY) AS item_age_days
FROM people p
JOIN {{staging.monday.item}} i ON i.item_id = p.item_id
LEFT JOIN {{staging.monday.board}} b ON b.board_id = i.board_id
LEFT JOIN {{staging.monday.user}} u ON u.user_id = p.user_id
-- One person can appear twice in the same column's JSON; keep them once.
QUALIFY ROW_NUMBER() OVER (PARTITION BY p.item_id, p.column_id, p.user_id ORDER BY i.updated_at DESC) = 1
