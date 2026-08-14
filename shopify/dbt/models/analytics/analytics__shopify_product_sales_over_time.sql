-- analytics__shopify_product_sales_over_time
-- BI-facing contract over the core model. See analytics/sales_over_time.sql for
-- why this layer exists even when it is a passthrough.

-- Cancelled orders are excluded here rather than in core: core keeps them so
-- their reversal events still land, and a report that shows a cancelled order's
-- sale without context is misleading. Voided orders are already gone in core.
-- Pending payments are deliberately kept - Shopify counts them as sales.

{{ config(materialized='view') }}

SELECT *
FROM {{ ref('core_shopify__product_sales_over_time') }}
WHERE cancelled_at IS NULL
