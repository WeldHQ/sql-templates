-- stg_linkedin_ads__creative
-- Thin wrapper over raw `creative`. Casts, renames, keeps the latest row per creative.
-- Grain: one row per creative. A creative is LinkedIn's ad.
--
-- `title` is filled by the connector from the post or share the creative promotes.
-- Creatives without a readable post (some formats, deleted posts) have a NULL title.

SELECT
    CAST(id AS STRING)                 AS creative_id,
    CAST(account_id AS STRING)         AS account_id,
    CAST(campaign_id AS STRING)        AS campaign_id,
    CAST(title AS STRING)              AS creative_title,
    CAST(intended_status AS STRING)    AS intended_status,
    CAST(is_serving AS BOOL)           AS is_serving,
    CAST(is_test AS BOOL)              AS is_test,
    CAST(content_reference AS STRING)  AS content_reference,
    CAST(created_at AS TIMESTAMP)      AS created_at
FROM {{ source('linkedin_ads', 'creative') }}
QUALIFY ROW_NUMBER() OVER (PARTITION BY account_id, id ORDER BY _weld_synced DESC) = 1
