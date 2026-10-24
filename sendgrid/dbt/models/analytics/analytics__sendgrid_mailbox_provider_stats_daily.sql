-- analytics__sendgrid_mailbox_provider_stats_daily
-- BI-facing contract over the core model. Dashboards bind to this name so core can
-- change without breaking them; add BI-specific shaping here rather than in core.

{{ config(materialized='view') }}

SELECT * FROM {{ ref('core_sendgrid__mailbox_provider_stats_daily') }}
