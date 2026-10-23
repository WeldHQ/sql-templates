-- core_app_store_connect__downloads_and_deletions
-- Installs and deletions by type, the Installations and Deletions view of App
-- Analytics: first-time downloads, redownloads, updates, restores and deletions.
--
-- Grain: one row per day x app x territory x source type x device.
-- Depends on: staging.app_store_connect.installs_deletions
--
-- Opted-in users only, with rows under five users suppressed by Apple, so totals
-- sit below the units in sales_and_proceeds. Use this model for mix and trend
-- (which source, which territory, how many deletions per install), and
-- sales_and_proceeds for absolute download counts.
--
-- INSTALLS, NOT DOWNLOADS. Every column counts install or delete events on a
-- device. Apple labels each install with the download that caused it: a
-- first-time download is the first Get or Buy on an Apple ID, a redownload is the
-- same account installing again. App Store Connect's own download figures come
-- from a separate Downloads report, counted per account and including pre-orders,
-- which the connector does not sync. Expect these to run close to, not equal to,
-- the downloads shown in App Analytics.
--
-- Apple documents four install types: first-time download, redownload, manual
-- update and restore. Anything else Apple sends lands in other_installs, so the
-- type columns always add up to total_installs.

SELECT
    date_day,
    app_apple_id,
    ANY_VALUE(app_name)                                                         AS app_name,
    territory,
    source_type,
    device,

    SUM(IF(event = 'Install' AND download_type = 'First-time download', event_count, 0)) AS first_time_downloads,
    SUM(IF(event = 'Install' AND download_type = 'Redownload', event_count, 0))          AS redownloads,
    SUM(IF(event = 'Install' AND download_type = 'Manual update', event_count, 0))       AS manual_updates,
    SUM(IF(event = 'Install' AND download_type = 'Restore', event_count, 0))             AS restores,
    SUM(IF(event = 'Install' AND COALESCE(download_type, '') NOT IN
           ('First-time download', 'Redownload', 'Manual update', 'Restore'), event_count, 0))
                                                                                         AS other_installs,
    SUM(IF(event = 'Install', event_count, 0))                                           AS total_installs,
    SUM(IF(event = 'Delete', event_count, 0))                                            AS deletions,

    -- New installs from people who chose to get the app, as opposed to updates and
    -- restores of an app they already had.
    SUM(IF(event = 'Install' AND download_type IN ('First-time download', 'Redownload'), event_count, 0))
                                                                                         AS acquisition_installs
FROM {{ ref('stg_app_store_connect__installs_deletions') }}
GROUP BY date_day, app_apple_id, territory, source_type, device
