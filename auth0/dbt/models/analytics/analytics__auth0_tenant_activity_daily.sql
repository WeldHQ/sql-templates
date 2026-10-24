-- analytics__auth0_tenant_activity_daily
-- BI-facing contract over the core model. See the README for why this layer exists
-- even when it is a passthrough.

{{ config(materialized='view') }}

SELECT * FROM {{ ref('core_auth0__tenant_activity_daily') }}
