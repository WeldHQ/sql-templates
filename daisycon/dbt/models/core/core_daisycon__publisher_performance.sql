-- core_daisycon__publisher_performance
-- Affiliate results per publisher, Daisycon's statistics grouped by publisher: clicks,
-- transactions by status, commission, revenue, and the rates affiliate managers
-- steer on (conversion rate, approval rate, cost of sale, commission per click).
--
-- Grain: advertiser_id x publisher_id, totalled over the sync window. Currency: per row.
-- Depends on: staging.daisycon.statistics_by_publisher, .advertiser
--
-- No date column: Daisycon returns these statistics as totals for a date range,
-- and the window is set by the sync (12 months back on a full sync by default).
-- Sync the stream in full mode so every row covers the same window. Rates are
-- ratios of sums; re-sum and divide again when you roll rows up.
--
-- approval_rate only counts transactions that have been judged: open ones are left
-- out of both sides. cost_of_sale divides program commission by the revenue your
-- tracking reported for the same transactions.

SELECT
    s.advertiser_id,
    a.advertiser_name,
    s.publisher_id,
    s.publisher_name,
    s.currency,

    s.clicks,
    s.unique_clicks,
    s.transactions,
    s.transaction_parts,
    s.open_transactions,
    s.approved_transactions,
    s.disapproved_transactions,
    s.revenue,
    s.commission,
    s.program_commission,
    s.open_program_commission,
    s.approved_program_commission,
    s.disapproved_program_commission,
    s.cpc_clicks,
    s.cpc_commission,

    SAFE_DIVIDE(s.transactions, s.unique_clicks)                  AS conversion_rate,
    SAFE_DIVIDE(s.approved_transactions,
                s.approved_transactions + s.disapproved_transactions) AS approval_rate,
    SAFE_DIVIDE(s.program_commission, s.revenue)                  AS cost_of_sale,
    SAFE_DIVIDE(s.program_commission, s.clicks)                  AS program_commission_per_click,
    SAFE_DIVIDE(s.revenue, s.transactions)                        AS average_order_value,
    s.ecpc                                                        AS daisycon_ecpc
FROM {{ ref('stg_daisycon__statistics_by_publisher') }} s
-- advertiser is one row per id after staging, so this join cannot fan out.
LEFT JOIN {{ ref('stg_daisycon__advertiser') }} a
    ON a.advertiser_id = s.advertiser_id
