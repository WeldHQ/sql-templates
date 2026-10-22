-- staging.grin.campaign_payable
-- Thin wrapper over raw `campaign_payable`: one row per amount owed to a creator
-- on a campaign (a flat fee, a commission, a bonus). Voided payables are kept and
-- flagged; core excludes them.
--
-- `usd_amount` is Grin's own conversion of `amount` to US dollars. Core sums
-- usd_amount so creators paid in different currencies add up. payment_id is set
-- once the payable has been included in a payment run.
--
-- Single Grin account; see staging.grin.campaign.

SELECT
    'account_1'                                  AS grin_account,
    CAST(id AS STRING)                           AS payable_id,
    CAST(campaign_id AS STRING)                  AS campaign_id,
    CAST(contact_id AS STRING)                   AS contact_id,
    NULLIF(CAST(payment_id AS STRING), '')       AS payment_id,
    CAST(amount AS NUMERIC)                      AS amount,
    UPPER(NULLIF(CAST(currency AS STRING), ''))  AS currency,
    CAST(usd_amount AS NUMERIC)                  AS usd_amount,
    NULLIF(CAST(status AS STRING), '')           AS status,
    NULLIF(CAST(payment_status AS STRING), '')   AS payment_status,
    COALESCE(CAST(is_voided AS BOOL), FALSE)     AS is_voided,
    CAST(due_at AS TIMESTAMP)                    AS due_at,
    CAST(created_at AS TIMESTAMP)                AS created_at
FROM {{raw.grin.campaign_payable}}
WHERE id IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY id ORDER BY updated_at DESC, _weld_synced DESC) = 1
