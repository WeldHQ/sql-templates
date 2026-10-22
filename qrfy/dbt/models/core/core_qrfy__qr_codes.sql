-- core_qrfy__qr_codes
-- Every QR code in the account with QRFY's lifetime scan counter: the My QR Codes list.
--
-- Grain: one row per QR code, as of the last sync.
-- Depends on: staging.qrfy.qr
--
-- `lifetime_scans` is QRFY's own total and is the number to reconcile the scan models
-- against: summed over all time, scans_daily.scans for a code should approach it. The two
-- are not joined here because scan rows carry the short link, not the code id.
-- `scans_to_limit` is how many scans remain before a code with a scan limit stops.

SELECT
    qr_id,
    qr_name,
    qr_type,
    folder,
    is_active,
    is_stopped,
    short_code,
    hostname,
    final_url,
    lifetime_scans,
    scan_limit,
    IF(scan_limit > 0, scan_limit - lifetime_scans, NULL)       AS scans_to_limit,
    created_at,
    DATE_DIFF(CURRENT_DATE(), DATE(created_at), DAY)            AS age_days,
    SAFE_DIVIDE(lifetime_scans,
        GREATEST(DATE_DIFF(CURRENT_DATE(), DATE(created_at), DAY), 1)) AS avg_scans_per_day
FROM {{ ref('stg_qrfy__qr') }}
