-- core_esmiley__registration_point_tree
-- Each registration point with its top-level area and full path, so waste can be
-- rolled up to "Kitchen" or "Buffet" whatever level it was registered at.
-- Grain: registration point.
--
-- Walks parent_id up to the root, at most ten levels.

WITH RECURSIVE tree AS (
    SELECT
        registration_point_id,
        registration_point_id      AS ancestor_id,
        parent_id                  AS next_parent_id,
        registration_point_name    AS path,
        0                          AS depth
    FROM {{ ref('stg_esmiley__registration_point') }}

    UNION ALL

    SELECT
        t.registration_point_id,
        p.registration_point_id,
        p.parent_id,
        CONCAT(p.registration_point_name, ' > ', t.path),
        t.depth + 1
    FROM tree t
    JOIN {{ ref('stg_esmiley__registration_point') }} p
      ON p.registration_point_id = t.next_parent_id
    WHERE t.depth < 10
)

SELECT
    t.registration_point_id,
    rp.registration_point_name,
    rp.account_id,
    t.ancestor_id                       AS root_registration_point_id,
    root.registration_point_name        AS area,
    t.path,
    t.depth                             AS level,
    rp.is_active,
    rp.is_deleted
FROM tree t
JOIN {{ ref('stg_esmiley__registration_point') }} rp USING (registration_point_id)
JOIN {{ ref('stg_esmiley__registration_point') }} root ON root.registration_point_id = t.ancestor_id
QUALIFY ROW_NUMBER() OVER (PARTITION BY t.registration_point_id ORDER BY t.depth DESC) = 1
