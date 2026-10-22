-- stg_dandomain_webshop__order_status_code
-- The shop's names for its order statuses, one row per status. The raw table holds
-- one row per status per language; the title in the alphabetically first language
-- is kept, so the join from orders cannot fan out.

SELECT
    'shop_1'                                        AS dandomain_shop,
    CAST(id AS INT64)                               AS status_id,
    ARRAY_AGG(NULLIF(TRIM(CAST(title AS STRING)), '') IGNORE NULLS
              ORDER BY language_iso LIMIT 1)[SAFE_OFFSET(0)] AS status_title
FROM {{ source('dandomain_webshop', 'order_status_code') }}
WHERE id IS NOT NULL
GROUP BY id
