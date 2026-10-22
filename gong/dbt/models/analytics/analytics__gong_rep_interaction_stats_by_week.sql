-- analytics__gong_rep_interaction_stats_by_week
-- BI-facing contract over the core model. Dashboards bind here so core can be
-- renamed or re-grained without breaking them. A passthrough on purpose.

{{ config(materialized='view') }}

SELECT * FROM {{ ref('core_gong__rep_interaction_stats_by_week') }}
