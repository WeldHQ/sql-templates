-- core_qrfy__scans_daily
-- Scans per QR code per day: QRFY's Statistics chart, total and unique scans, by code.
--
-- Grain: one row per day (UTC) x QR code (scan_url).
-- Depends on: staging.qrfy.analytics
--
-- `unique_scans` counts scans QRFY flagged as a visitor's first. Unique visitors are
-- per code, so unique scans summed across codes count a person once per code they
-- scanned.
-- `qr_name` and `folder` are the latest values seen in the scan rows for that code, so a
-- renamed code shows its current name on every day.

WITH latest_label AS (
    SELECT
        scan_url,
        ARRAY_AGG(STRUCT(qr_name, folder) ORDER BY scanned_at DESC LIMIT 1)[OFFSET(0)] AS label
    FROM {{ ref('stg_qrfy__analytics') }}
    GROUP BY 1
),

daily AS (
    SELECT
        DATE(scanned_at)                                        AS date,
        scan_url,
        COUNT(*)                                                AS scans,
        COUNTIF(is_unique_visitor)                              AS unique_scans,
        COUNT(DISTINCT country_iso)                             AS countries
    FROM {{ ref('stg_qrfy__analytics') }}
    GROUP BY 1, 2
)

SELECT
    d.date,
    d.scan_url,
    l.label.qr_name                                             AS qr_name,
    l.label.folder                                              AS folder,
    d.scans,
    d.unique_scans,
    d.countries
FROM daily d
LEFT JOIN latest_label l ON l.scan_url = d.scan_url
