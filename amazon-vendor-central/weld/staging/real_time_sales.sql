-- staging.amazon_vendor.real_time_sales
-- Thin wrapper over raw `vendor_real_time_sales_report`. Casts, renames,
-- de-duplicates. No other logic.
--
-- Hourly ordered units and revenue per ASIN, roughly two hours behind live. Useful
-- for exactly two things: watching a Prime Day or a promotion as it happens, and
-- catching a mid-day collapse in a top ASIN before the daily report shows it
-- tomorrow.
--
-- DO NOT USE IT FOR ANYTHING THAT HAS TO ADD UP. Two reasons, both structural:
--
--   * 29-day retention. Amazon deletes it. Any trend longer than a month must come
--     from staging.amazon_vendor.sales.
--   * It disagrees with the daily report, by design. This report is optimised for
--     latency over accuracy and does not wait for cancellations or adjustments to
--     settle. Amazon documents the difference. Reconciling the two is not a bug to
--     fix, so do not spend a week on it.
--
-- Timestamps are UTC. Amazon's vendor retail analytics reports are in PST regardless
-- of marketplace, so an hourly series joined to a daily one without converting will
-- be misaligned by 7-8 hours - which puts an evening spike on the wrong day.

SELECT
    'vendor_1'                                                  AS amazon_vendor,
    marketplace,
    hour_start_at,
    hour_end_at,
    DATE(hour_start_at)                                         AS date_utc,
    asin,
    ordered_units,
    ordered_revenue
FROM (
    SELECT
        UPPER(NULLIF(TRIM(CAST(marketplace_id AS STRING)), ''))     AS marketplace,
        CAST(start_time AS TIMESTAMP)                               AS hour_start_at,
        CAST(end_time AS TIMESTAMP)                                 AS hour_end_at,
        UPPER(NULLIF(TRIM(CAST(asin AS STRING)), ''))               AS asin,

        -- Can be negative: more cancellations than orders in the hour.
        CAST(ordered_units AS INT64)                                AS ordered_units,
        CAST(ordered_revenue AS NUMERIC)                            AS ordered_revenue,

        ROW_NUMBER() OVER (
            PARTITION BY marketplace_id, CAST(start_time AS TIMESTAMP), asin
            ORDER BY _weld_synced DESC
        ) AS generation_rank
    FROM {{raw.amazon_vendor_central.vendor_real_time_sales_report}}
)
WHERE generation_rank = 1
