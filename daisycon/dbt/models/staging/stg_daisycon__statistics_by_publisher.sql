-- stg_daisycon__statistics_by_publisher
-- Thin wrapper over raw `advertiser_statistics_by_publisher`, Daisycon advertiser
-- statistics grouped by publisher.
-- Casts, renames, keeps the latest row per key. No other logic.
--
-- Grain: advertiser x publisher, totalled over the sync window (see below).
--
-- THE ROWS ARE TOTALS, NOT DAYS. Daisycon returns one row per publisher for a date range.
-- After a full sync the range runs from the connection's start date (12 months back
-- by default) to now; after an incremental sync, rows for publisher active since the
-- previous sync cover only that shorter period. Sync this table in full mode, or
-- the rows mix windows of different lengths.
--
-- Transactions are counted on the transaction date, Daisycon's default. Amounts are
-- in currency_code. Daisycon's field names are kept close to the API:
-- transaction_amount is the "commission" and transaction_program_amount the
-- "program commission" of the transaction endpoints; revenue is the order value
-- your tracking reported.

SELECT * EXCEPT (row_rank)
FROM (
    SELECT
        CAST(advertiser_id AS STRING)                 AS advertiser_id,
        CAST(publisher_id AS STRING)                  AS publisher_id,
        CAST(publisher_name AS STRING)                AS publisher_name,
        UPPER(CAST(currency_code AS STRING))          AS currency,
        COALESCE(click_raw, 0)                        AS clicks,
        COALESCE(click_unique, 0)                     AS unique_clicks,
        COALESCE(cpc_raw, 0)                          AS cpc_clicks,
        COALESCE(cpc_unique, 0)                       AS cpc_unique_clicks,
        CAST(COALESCE(cpc_amount, 0) AS NUMERIC)      AS cpc_commission,
        COALESCE(transaction_unique, 0)               AS transactions,
        COALESCE(transaction_parts, 0)                AS transaction_parts,
        CAST(COALESCE(transaction_amount, 0) AS NUMERIC)                      AS commission,
        CAST(COALESCE(transaction_program_amount, 0) AS NUMERIC)              AS program_commission,
        CAST(COALESCE(transaction_revenue, 0) AS NUMERIC)                     AS revenue,
        COALESCE(transaction_open, 0)                                         AS open_transactions,
        CAST(COALESCE(transaction_open_amount, 0) AS NUMERIC)                 AS open_commission,
        CAST(COALESCE(transaction_open_program_amount, 0) AS NUMERIC)         AS open_program_commission,
        COALESCE(transaction_approved, 0)                                     AS approved_transactions,
        CAST(COALESCE(transaction_approved_amount, 0) AS NUMERIC)             AS approved_commission,
        CAST(COALESCE(transaction_approved_program_amount, 0) AS NUMERIC)     AS approved_program_commission,
        COALESCE(transaction_disapproved, 0)                                  AS disapproved_transactions,
        CAST(COALESCE(transaction_disapproved_amount, 0) AS NUMERIC)          AS disapproved_commission,
        CAST(COALESCE(transaction_disapproved_program_amount, 0) AS NUMERIC)  AS disapproved_program_commission,
        CAST(ecpc AS NUMERIC)                                                 AS ecpc,
        ROW_NUMBER() OVER (PARTITION BY advertiser_id, publisher_id ORDER BY _weld_synced DESC) AS row_rank
    FROM {{ source('daisycon', 'advertiser_statistics_by_publisher') }}
)
WHERE row_rank = 1
