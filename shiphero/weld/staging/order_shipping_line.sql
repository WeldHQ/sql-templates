-- staging.shiphero.order_shipping_line
-- Thin wrapper over raw `order_shipping_line`: the shipping option and price the
-- store charged the customer, as sent to ShipHero. At most one row per order.
--
-- This is shipping REVENUE (what the customer paid), not shipping cost. Cost is on
-- the shipping labels, see staging.shiphero.shipment_shipping_label.

SELECT
    'account_1'                                AS shiphero_account,
    CAST(order_id AS STRING)                   AS order_id,
    NULLIF(TRIM(CAST(title AS STRING)), '')    AS shipping_title,
    NULLIF(TRIM(CAST(carrier AS STRING)), '')  AS requested_carrier,
    NULLIF(TRIM(CAST(method AS STRING)), '')   AS requested_method,
    SAFE_CAST(price AS NUMERIC)                AS shipping_charged
FROM {{raw.shiphero.order_shipping_line}}
