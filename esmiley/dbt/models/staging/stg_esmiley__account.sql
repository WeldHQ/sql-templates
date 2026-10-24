-- stg_esmiley__account
-- Thin wrapper over raw `account`. One row per eSmiley account, typically one per
-- kitchen or site.

SELECT
    CAST(id AS INT64)           AS account_id,
    CAST(company AS STRING)     AS company,
    CAST(nickname AS STRING)    AS account_name,
    CAST(city AS STRING)        AS city,
    CAST(country AS STRING)     AS country
FROM {{ source('esmiley', 'account') }}
WHERE id IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY CAST(id AS INT64) ORDER BY _weld_synced DESC) = 1
