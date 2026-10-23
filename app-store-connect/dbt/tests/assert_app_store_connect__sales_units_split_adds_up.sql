-- Units sold minus units refunded equals net units, on every row.
-- Refunds arrive as negative units; if this fails, the sign handling in
-- stg_app_store_connect__sales_report has changed and refunds are being counted
-- as sales.

SELECT *
FROM {{ ref('core_app_store_connect__sales_and_proceeds') }}
WHERE units_sold - units_refunded != units
