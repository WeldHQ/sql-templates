-- Label cost is never negative.
--
-- ShipHero sends label cost as a string. A negative value means either a carrier
-- credit has been recorded as a label, or the string was parsed from a format
-- staging did not expect. Either way the daily shipping cost is understated.
--
-- Returns zero rows when every label cost is zero or positive.

SELECT
    shiphero_account,
    shipping_label_id,
    shipment_id,
    label_cost
FROM {{ ref('stg_shiphero__shipment_shipping_label') }}
WHERE label_cost < 0
