-- core_younium__account_cmrr
-- Current committed MRR, ACV and TCV per customer account, as Younium computes
-- them, with each account's share of total CMRR.
-- Grain: one row per account, as of the last sync. Not history: for movements over
-- time use core.younium.mrr_movements.
--
-- cmrr is in the account's own currency; cmrr_base and the share are in the
-- Younium base currency, so they add up across accounts.

SELECT
    account_id,
    account_number,
    account_name,
    account_type,
    parent_account_id,
    country,
    is_inactive,
    created_at,
    currency,
    cmrr,
    base_currency,
    cmrr_base,
    cmrr_base * 12                                        AS carr_base,
    acv_base,
    tcv_base,
    SAFE_DIVIDE(cmrr_base, SUM(cmrr_base) OVER ())        AS share_of_total_cmrr,
    RANK() OVER (ORDER BY cmrr_base DESC)                 AS cmrr_rank
FROM {{ ref('stg_younium__account') }}
