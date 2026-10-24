-- analytics__iterable_email_campaign_performance
-- BI-facing contract over the core model. Dashboards bind to this name so core can
-- change without breaking them; add BI-specific shaping here rather than in core.

{{ config(materialized='view') }}

SELECT * FROM {{ ref('core_iterable__email_campaign_performance') }}
