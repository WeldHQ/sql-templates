-- Unique scans can never exceed total scans, on any row of either scan model.
--
-- unique_scans counts rows QRFY flagged as a visitor's first scan, so it is a subset of
-- scans by construction. If this fires, the flag was cast wrongly in staging.

SELECT 'scans_daily' AS model, CAST(date AS STRING) AS period, scan_url
FROM {{ ref('core_qrfy__scans_daily') }}
WHERE unique_scans > scans

UNION ALL

SELECT 'scans_by_location_and_device', CAST(month AS STRING), scan_url
FROM {{ ref('core_qrfy__scans_by_location_and_device') }}
WHERE unique_scans > scans
