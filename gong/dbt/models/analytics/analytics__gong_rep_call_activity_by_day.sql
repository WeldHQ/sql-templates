-- analytics__gong_rep_call_activity_by_day
-- BI-facing contract over the core model. Dashboards bind here so core can be
-- renamed or re-grained without breaking them. A passthrough on purpose.

{{ config(materialized='view') }}

SELECT * FROM {{ ref('core_gong__rep_call_activity_by_day') }}
