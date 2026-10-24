-- analytics__google_play_store_listing_conversion
-- BI-facing contract over the core model. See the README for why this layer exists
-- even when it is a passthrough.

{{ config(materialized='view') }}

SELECT * FROM {{ ref('core_google_play__store_listing_conversion') }}
