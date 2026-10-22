-- stg_tiktok_shop__shop
-- One row per shop the connector syncs, carrying the timezone every report
-- localises to. There is no shop table in the sync, so the shop list is read off
-- the orders.
--
-- SET report_timezone BEFORE TRUSTING ANY DAILY NUMBER. TikTok sends every
-- timestamp as UTC, while Seller Center reports in the shop's local time (US shops
-- report in Pacific time). Left at 'UTC', every late-evening order lands on the
-- next day and daily totals will not match Seller Center. Use a CASE on shop_id if
-- your shops sit in different regions.

SELECT DISTINCT
    'account_1'               AS tiktok_account,
    CAST(shop_id AS STRING)   AS shop_id,
    'UTC'                     AS report_timezone
FROM {{ source('tiktok_shop', 'order') }}
