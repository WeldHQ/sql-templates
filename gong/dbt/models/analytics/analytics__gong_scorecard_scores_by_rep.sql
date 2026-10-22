-- analytics__gong_scorecard_scores_by_rep
-- BI-facing contract over the core model. Dashboards bind here so core can be
-- renamed or re-grained without breaking them. A passthrough on purpose.

{{ config(materialized='view') }}

SELECT * FROM {{ ref('core_gong__scorecard_scores_by_rep') }}
