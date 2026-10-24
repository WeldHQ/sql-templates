-- analytics__qrfy_scans_by_location_and_device
-- BI-facing contract over the core model. Dashboards bind to this name so core can
-- change without breaking them; add BI-specific shaping here rather than in core.

{{ config(materialized='view') }}

SELECT * FROM {{ ref('core_qrfy__scans_by_location_and_device') }}
