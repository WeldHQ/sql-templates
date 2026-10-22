-- analytics__wordpress_publishing_cadence
-- BI-facing contract over the core model. See the README for why this layer exists
-- even when it is a passthrough.

{{ config(materialized='view') }}

SELECT * FROM {{ ref('core_wordpress__publishing_cadence') }}
