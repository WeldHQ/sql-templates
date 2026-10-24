-- analytics__younium_account_cmrr
-- BI-facing contract over the core model. Dashboards bind to this name so core can
-- change without breaking them; it is a passthrough on purpose.

{{ config(materialized='view') }}

SELECT * FROM {{ ref('core_younium__account_cmrr') }}
