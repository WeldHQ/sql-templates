-- staging.grin.campaign
-- Thin wrapper over raw `campaign`: one row per Grin campaign. Casts, renames.
--
-- `budget` is the planned budget entered on the campaign, in the account's
-- currency. The proposal and content windows are the dates the campaign accepts
-- creator proposals and expects content.
--
-- Single Grin account. To add another, UNION ALL a second block below pointing at
-- that connector with a different grin_account label. Keep it in staging so the
-- core models never have to know how many accounts there are.

SELECT
    'account_1'                                       AS grin_account,
    CAST(id AS STRING)                                AS campaign_id,
    CAST(brand_id AS STRING)                          AS brand_id,
    NULLIF(TRIM(CAST(internal_title AS STRING)), '')  AS campaign_name,
    NULLIF(TRIM(CAST(influencer_title AS STRING)), '') AS campaign_public_name,
    CAST(budget AS NUMERIC)                           AS budget,
    NULLIF(CAST(compensation AS STRING), '')          AS compensation,
    NULLIF(CAST(payment_method AS STRING), '')        AS payment_method,
    CAST(date_proposals_start AS TIMESTAMP)           AS proposals_start_at,
    CAST(date_proposals_end AS TIMESTAMP)             AS proposals_end_at,
    CAST(date_content_start AS TIMESTAMP)             AS content_start_at,
    CAST(date_content_end AS TIMESTAMP)               AS content_end_at,
    CAST(created_at AS TIMESTAMP)                     AS created_at,
    CAST(updated_at AS TIMESTAMP)                     AS updated_at
FROM {{raw.grin.campaign}}
WHERE id IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY id ORDER BY updated_at DESC, _weld_synced DESC) = 1
