-- stg_apple_ads__campaign_report
-- Thin wrapper over raw `campaign_reports`. Casts, renames, de-duplicates.
-- No other logic.
--
-- Grain: one row per campaign per day.
--
-- Dates are days in the organization's reporting time zone (Apple's default,
-- which the connector does not override), so they line up with the Apple Ads UI.
-- Spend is in the organization's currency, in whole units.
--
-- The install columns use Apple's pre-v5 field names (installs, new_downloads,
-- redownloads). Apple's v5 reporting API renamed them to tapInstalls,
-- tapNewDownloads and tapRedownloads, so in your warehouse they may be empty.
-- Check before relying on them; see the README.
--
-- The connector re-reads the full lookback window on every sync, so the latest
-- synced row per campaign and day wins.

SELECT * EXCEPT (row_rank)
FROM (
    SELECT
        -- Parses YYYY-MM-DD, falling back to MM-DD-YYYY.
        COALESCE(
            SAFE_CAST(LEFT(CAST(date AS STRING), 10) AS DATE),
            SAFE.PARSE_DATE('%m-%d-%Y', LEFT(CAST(date AS STRING), 10))
        )                                               AS date_day,
        CAST(campaign_id AS STRING)                     AS campaign_id,
        CAST(campaign_name AS STRING)                   AS campaign_name,
        CAST(country_or_region AS STRING)               AS country_or_region,
        UPPER(CAST(spend_currency AS STRING))           AS currency,
        CAST(COALESCE(spend_amount, 0) AS NUMERIC)      AS spend,
        CAST(COALESCE(impressions, 0) AS INT64)         AS impressions,
        CAST(COALESCE(taps, 0) AS INT64)                AS taps,
        CAST(installs AS NUMERIC)                       AS installs,
        CAST(new_downloads AS NUMERIC)                  AS new_downloads,
        CAST(redownloads AS NUMERIC)                    AS redownloads,
        ROW_NUMBER() OVER (
            PARTITION BY campaign_id, date
            ORDER BY _weld_synced DESC
        ) AS row_rank
    FROM {{ source('apple_ads', 'campaign_reports') }}
)
WHERE row_rank = 1
