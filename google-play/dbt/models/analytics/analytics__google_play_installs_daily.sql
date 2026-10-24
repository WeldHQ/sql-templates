-- analytics__google_play_installs_daily
-- BI-facing contract over the core model. See the README for why this layer exists
-- even when it is a passthrough.

{{ config(materialized='view') }}

SELECT * FROM {{ ref('core_google_play__installs_daily') }}
