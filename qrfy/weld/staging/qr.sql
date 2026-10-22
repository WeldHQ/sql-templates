-- staging.qrfy.qr
-- Thin wrapper over raw `qr`: one row per QR code in the account, current state, with
-- QRFY's lifetime scan counter. Casts and renames.
--
-- Grain: qr_id.
-- `scans` is QRFY's own running total for the code, the number shown next to it in the
-- dashboard. Synced in full on every run.

SELECT
    CAST(id AS STRING)                          AS qr_id,
    CAST(name AS STRING)                        AS qr_name,
    LOWER(CAST(type AS STRING))                 AS qr_type,
    CAST(folder_id AS STRING)                   AS folder_id,
    CAST(folder_name AS STRING)                 AS folder,
    CAST(status AS BOOL)                        AS is_active,
    CAST(stopped AS BOOL)                       AS is_stopped,
    CAST(uri AS STRING)                         AS short_code,
    CAST(hostname AS STRING)                    AS hostname,
    CAST(final_url AS STRING)                   AS final_url,
    CAST(scans AS INT64)                        AS lifetime_scans,
    CAST(scan_limit AS INT64)                   AS scan_limit,
    CAST(created_at AS TIMESTAMP)               AS created_at,
    CAST(updated_at AS TIMESTAMP)               AS updated_at
FROM {{raw.qrfy.qr}}
