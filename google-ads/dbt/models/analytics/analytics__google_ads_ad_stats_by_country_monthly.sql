-- analytics__google_ads_ad_stats_by_country_monthly
-- BI-facing contract over the core model. Dashboards bind here so core can
-- change without breaking them. A passthrough on purpose.

{{ config(materialized='view') }}

SELECT * FROM {{ ref('core_google_ads__ad_stats_by_country_monthly') }}
