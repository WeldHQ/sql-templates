-- staging.grin.content
-- Thin wrapper over raw `content`: one row per piece of creator content Grin has
-- captured (a post, story, reel or video), with the campaign and creator it belongs
-- to. Deleted content is dropped here.
--
-- Read from the account-wide content list, not the per-campaign copy
-- (`campaign_content`), which holds the same rows once per campaign and has no
-- stats attached.
--
-- Single Grin account; see staging.grin.campaign.

SELECT
    'account_1'                                   AS grin_account,
    CAST(id AS STRING)                            AS content_id,
    CAST(campaign_id AS STRING)                   AS campaign_id,
    CAST(activation_id AS STRING)                 AS activation_id,
    CAST(contact_id AS STRING)                    AS contact_id,
    NULLIF(CAST(network_name AS STRING), '')      AS network_name,
    NULLIF(CAST(network_slug AS STRING), '')      AS network_slug,
    COALESCE(CAST(is_story AS BOOL), FALSE)       AS is_story,
    CAST(posted_at AS TIMESTAMP)                  AS posted_at,
    CAST(created_at AS TIMESTAMP)                 AS created_at,
    CAST(updated_at AS TIMESTAMP)                 AS updated_at
FROM {{raw.grin.content}}
WHERE id IS NOT NULL
  AND deleted_at IS NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY id ORDER BY updated_at DESC, _weld_synced DESC) = 1
