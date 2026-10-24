-- staging.toast_analytics.payout
-- Thin wrapper over raw `analytics_payout_by_settled_date`: what Toast paid out
-- per restaurant and settlement date, after card fees and withholdings. One row
-- per restaurant x settled date.

SELECT
    CAST(restaurant_guid AS STRING)                     AS restaurant_id,
    CAST(restaurant_name AS STRING)                     AS restaurant_name,
    COALESCE(
        SAFE.PARSE_DATE('%Y%m%d', CAST(settled_date AS STRING)),
        SAFE_CAST(LEFT(CAST(settled_date AS STRING), 10) AS DATE)
    )                                                   AS settled_date,
    CAST(sales_period_start_date_time AS TIMESTAMP)     AS sales_period_start_at,
    CAST(sales_period_end_date_time AS TIMESTAMP)       AS sales_period_end_at,
    CAST(transaction_count AS INT64)                    AS transactions,
    CAST(payment_amount AS FLOAT64)                     AS payment_amount,
    CAST(refund_amount AS FLOAT64)                      AS refund_amount,
    CAST(total_fee_amount AS FLOAT64)                   AS fee_amount,
    CAST(withholding_amount AS FLOAT64)                 AS withholding_amount,
    CAST(payout_amount AS FLOAT64)                      AS payout_amount,
    CAST(payout_status AS STRING)                       AS payout_status
FROM {{raw.toast_analytics.analytics_payout_by_settled_date}}
WHERE restaurant_guid IS NOT NULL
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY CAST(restaurant_guid AS STRING), CAST(settled_date AS STRING)
    ORDER BY _weld_synced DESC
) = 1
