-- Revenue per answer cannot be negative, and an answer cannot have revenue without
-- orders.
--
-- A negative order_value would mean the response captured a refund or an edited
-- order rather than the purchase; a row here is worth checking against the order in
-- Shopify before trusting the attribution split.

SELECT *
FROM {{ ref('core_zigpoll__attribution_by_answer') }}
WHERE revenue < 0
   OR (orders = 0 AND revenue IS NOT NULL)
