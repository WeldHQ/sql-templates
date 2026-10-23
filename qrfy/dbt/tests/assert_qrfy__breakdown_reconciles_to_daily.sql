-- The location and device breakdown adds back up to the daily scan totals, per code per
-- month, and scans_daily is one row per day per code.
--
-- Both models read the same scan rows. A mismatch means a grouping key went NULL-unsafe
-- or a join was added that fans out; a duplicate day means the label lookup is no longer
-- one row per code.

WITH daily AS (
    SELECT DATE_TRUNC(date, MONTH) AS month, scan_url, SUM(scans) AS scans
    FROM {{ ref('core_qrfy__scans_daily') }}
    GROUP BY 1, 2
),

breakdown AS (
    SELECT month, scan_url, SUM(scans) AS scans
    FROM {{ ref('core_qrfy__scans_by_location_and_device') }}
    GROUP BY 1, 2
)

SELECT 'totals_differ' AS check_name, CAST(COALESCE(d.month, b.month) AS STRING) AS month,
       COALESCE(d.scan_url, b.scan_url) AS scan_url
FROM daily d
FULL OUTER JOIN breakdown b
  ON b.month = d.month AND b.scan_url IS NOT DISTINCT FROM d.scan_url
WHERE COALESCE(d.scans, 0) != COALESCE(b.scans, 0)

UNION ALL

SELECT 'duplicate_day', CAST(date AS STRING), scan_url
FROM {{ ref('core_qrfy__scans_daily') }}
GROUP BY date, scan_url
HAVING COUNT(*) > 1
