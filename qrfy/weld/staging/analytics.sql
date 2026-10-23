-- staging.qrfy.analytics
-- Thin wrapper over raw `analytics`: QRFY's detailed scan report, one row per recorded
-- scan with where and on what device it happened. Casts and de-duplicates.
--
-- Grain: one scan, keyed as the raw table is: scan_url x scan time x country x
-- city x operating system x OS version.
-- Rows carry no QR id. `scan_url` is the QR code's short link and identifies the code;
-- `qr_name` and `folder` are the code's name and folder at the time of the report.
-- `is_unique_visitor` is QRFY's own flag for the first scan by a visitor, which is what
-- the "unique scans" figure in QRFY counts.

SELECT
    CAST(scan_url AS STRING)                    AS scan_url,
    CAST(name AS STRING)                        AS qr_name,
    CAST(folder AS STRING)                      AS folder,
    CAST(date AS TIMESTAMP)                     AS scanned_at,
    UPPER(CAST(country_iso AS STRING))          AS country_iso,
    CAST(country AS STRING)                     AS country,
    CAST(city AS STRING)                        AS city,
    CAST(os AS STRING)                          AS os,
    CAST(os_version AS STRING)                  AS os_version,
    COALESCE(CAST(unique_visitor AS BOOL), FALSE) AS is_unique_visitor,
    CAST(destination_url AS STRING)             AS destination_url
FROM {{raw.qrfy.analytics}}
WHERE date IS NOT NULL
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY scan_url, date, country_iso, city, os, os_version
    ORDER BY _weld_synced DESC
) = 1
