-- analytics__clickup_task_dependency_analysis
-- BI-facing contract over the core model. Dashboards bind here so core can
-- change without breaking them. A passthrough on purpose.

{{ config(materialized='view') }}

SELECT * FROM {{ ref('core_clickup__task_dependency_analysis') }}
