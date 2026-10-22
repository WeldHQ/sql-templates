-- stg_tiktok_shop__statement
-- Thin wrapper over raw `statement`: one row per settlement statement, which is
-- one payout cycle's worth of money for one shop.
--
-- statement_time arrives as Unix seconds. settlement_amount is TikTok's own total
-- for what the statement pays out, which is what the ledger is tested against.

SELECT
    'account_1'                                          AS tiktok_account,
    CAST(shop_id AS STRING)                              AS shop_id,
    CAST(id AS STRING)                                   AS statement_id,
    TIMESTAMP_SECONDS(CAST(statement_time AS INT64))     AS statement_at,
    UPPER(CAST(currency AS STRING))                      AS currency,
    UPPER(CAST(payment_status AS STRING))                AS payment_status,
    CAST(payment_id AS STRING)                           AS payment_id,
    CAST(revenue_amount AS NUMERIC)                      AS revenue_amount,
    CAST(fee_amount AS NUMERIC)                          AS fee_amount,
    CAST(shipping_cost_amount AS NUMERIC)                AS shipping_cost_amount,
    CAST(adjustment_amount AS NUMERIC)                   AS adjustment_amount,
    CAST(net_sales_amount AS NUMERIC)                    AS net_sales_amount,
    CAST(settlement_amount AS NUMERIC)                   AS settlement_amount
FROM {{ source('tiktok_shop', 'statement') }}
WHERE id IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY shop_id, id ORDER BY _weld_synced DESC) = 1
