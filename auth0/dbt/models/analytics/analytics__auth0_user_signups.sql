-- analytics__auth0_user_signups
-- BI-facing contract over the core model. See the README for why this layer exists
-- even when it is a passthrough.

{{ config(materialized='view') }}

SELECT * FROM {{ ref('core_auth0__user_signups') }}
