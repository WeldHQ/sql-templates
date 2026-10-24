-- staging.grin.campaign_conversion
-- Thin wrapper over raw `campaign_conversion`: one row per order Grin attributed
-- to a creator on a campaign, through their discount code or affiliate link.
--
-- `amount` is the order value and `commission_amount` the creator's commission
-- on it, both in `currency` (your store's currency). Voided conversions are kept
-- and flagged with their void_reason; core excludes them from revenue.
--
-- Read per campaign, so campaign_id is always set. The account-wide
-- `conversion` table carries conversions with an activation id but no campaign
-- id, so it cannot be split by campaign.
--
-- Single Grin account; see staging.grin.campaign.

SELECT
    'account_1'                                  AS grin_account,
    CAST(id AS STRING)                           AS conversion_id,
    CAST(campaign_id AS STRING)                  AS campaign_id,
    CAST(contact_id AS STRING)                   AS contact_id,
    LOWER(NULLIF(CAST(type AS STRING), ''))      AS conversion_type,
    CAST(order_id AS STRING)                     AS order_id,
    CAST(order_number AS STRING)                 AS order_number,
    CAST(amount AS NUMERIC)                      AS amount,
    CAST(commission_amount AS NUMERIC)           AS commission_amount,
    UPPER(NULLIF(CAST(currency AS STRING), ''))  AS currency,
    CAST(discount_code_id AS STRING)             AS discount_code_id,
    CAST(affiliate_link_id AS STRING)            AS affiliate_link_id,
    COALESCE(CAST(is_verified AS BOOL), FALSE)   AS is_verified,
    COALESCE(CAST(is_voided AS BOOL), FALSE)     AS is_voided,
    NULLIF(CAST(void_reason AS STRING), '')      AS void_reason,
    CAST(created_at AS TIMESTAMP)                AS converted_at,
    CAST(voided_at AS TIMESTAMP)                 AS voided_at
FROM {{raw.grin.campaign_conversion}}
WHERE id IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY id ORDER BY updated_at DESC, _weld_synced DESC) = 1
