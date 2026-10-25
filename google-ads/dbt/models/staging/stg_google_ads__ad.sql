-- stg_google_ads__ad
-- Thin wrapper over raw `ad` (Google's ad group ads). Casts, renames, parses the
-- final URL list, keeps the latest row per ad.
-- Grain: one row per account x ad group x ad. Google identifies an ad by its ad
-- group and ad ID together, so both are part of the key.
--
-- final_urls lands as a JSON array in a string column; final_url is its first
-- entry, which is the landing page Google serves for that ad.

SELECT * EXCEPT (row_rank)
FROM (
    SELECT
        CAST(account_id AS STRING)                 AS account_id,
        CAST(campaign_id AS STRING)                AS campaign_id,
        CAST(ad_group_id AS STRING)                AS ad_group_id,
        CAST(id AS STRING)                         AS ad_id,
        CAST(name AS STRING)                       AS ad_name,
        CAST(ad_type AS STRING)                    AS ad_type,
        CAST(status AS STRING)                     AS ad_status,
        JSON_VALUE(CAST(final_urls AS STRING), '$[0]') AS final_url,
        CAST(final_urls AS STRING)                 AS final_urls_json,
        CAST(final_url_suffix AS STRING)           AS final_url_suffix,
        CAST(display_url AS STRING)                AS display_url,
        ROW_NUMBER() OVER (
            PARTITION BY account_id, ad_group_id, id
            ORDER BY _weld_synced DESC
        ) AS row_rank
    FROM {{ source('google_ads', 'ad') }}
)
WHERE row_rank = 1
