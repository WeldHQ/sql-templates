-- core.qrfy.scans_by_location_and_device
-- Where and on what devices codes are scanned: QRFY's country, city and operating-system
-- breakdowns, per code per month.
--
-- Grain: one row per month (UTC) x QR code (scan_url) x country x city x operating system.
-- Depends on: staging.qrfy.analytics
--
-- Location is QRFY's IP-based estimate, so city is approximate and can be empty. OS
-- version is left out of the grain to keep rows readable; it is on the staging model if
-- you need it.

SELECT
    DATE_TRUNC(DATE(scanned_at), MONTH)                         AS month,
    scan_url,
    country_iso,
    country,
    city,
    os,
    COUNT(*)                                                    AS scans,
    COUNTIF(is_unique_visitor)                                  AS unique_scans
FROM {{staging.qrfy.analytics}}
GROUP BY 1, 2, 3, 4, 5, 6
