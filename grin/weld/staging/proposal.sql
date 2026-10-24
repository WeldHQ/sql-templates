-- staging.grin.proposal
-- Thin wrapper over raw `proposal`: one row per creator proposal on a campaign,
-- the record of a creator being invited to (or applying for) a campaign and how
-- far it got.
--
-- Lifecycle timestamps: accepted_at (the brand accepted), declined_at, agreed_at
-- (terms agreed) and completed_at (deliverables done). `price` is the agreed fee
-- for the proposal, in the account's currency.
--
-- Single Grin account; see staging.grin.campaign.

SELECT
    'account_1'                              AS grin_account,
    CAST(id AS STRING)                       AS proposal_id,
    CAST(campaign_id AS STRING)              AS campaign_id,
    CAST(contact_id AS STRING)               AS contact_id,
    CAST(price AS NUMERIC)                   AS price,
    COALESCE(CAST(has_product AS BOOL), FALSE) AS has_product,
    COALESCE(CAST(has_payment AS BOOL), FALSE) AS has_payment,
    COALESCE(CAST(agreed AS BOOL), FALSE)    AS is_agreed,
    COALESCE(CAST(is_complete AS BOOL), FALSE) AS is_complete,
    CAST(created_at AS TIMESTAMP)            AS created_at,
    CAST(accepted_at AS TIMESTAMP)           AS accepted_at,
    CAST(declined_at AS TIMESTAMP)           AS declined_at,
    CAST(agreed_at AS TIMESTAMP)             AS agreed_at,
    CAST(completed_at AS TIMESTAMP)          AS completed_at,
    CAST(updated_at AS TIMESTAMP)            AS updated_at
FROM {{raw.grin.proposal}}
WHERE id IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY id ORDER BY updated_at DESC, _weld_synced DESC) = 1
