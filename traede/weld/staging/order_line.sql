-- staging.traede.order_line
-- Thin wrapper over raw `order_line`. One row per order x variant: Traede keys an
-- order line by its variant, so the same variant cannot appear twice on one order.
--
-- UNITS: `price_before_discount`, `discount_amount` and `net_price` are PER UNIT on
-- a line (on the order header the same names are totals). `total_price` is the line
-- total ex VAT, quantity x net_price. Renamed so the difference is visible.
--
-- QUANTITIES: `quantity` is what was ordered and never decreases. `shipped` rises
-- when units are sent to the warehouse for picking, not when the customer receives
-- them. `invoiced` rises when an invoice for the order is booked.
--
-- `order_updated_at` is the parent order's updated_at at the time this line was
-- synced. Kept for auditing: a line whose stamp is older than its order's current
-- updated_at was not returned with the latest version of that order.

SELECT
    'account_1'                                AS traede_account,
    CAST(order_id AS STRING)                   AS order_id,
    CAST(variant_id AS STRING)                 AS variant_id,
    CAST(product_id AS STRING)                 AS product_id,

    CAST(quantity AS INT64)                    AS quantity_ordered,
    CAST(shipped AS INT64)                     AS quantity_shipped,
    CAST(invoiced AS INT64)                    AS quantity_invoiced,

    CAST(price_before_discount AS NUMERIC)     AS unit_price_before_discount,
    CAST(discount_amount AS NUMERIC)           AS unit_discount_amount,
    CAST(net_price AS NUMERIC)                 AS unit_net_price,
    CAST(total_price AS NUMERIC)               AS line_net_amount,
    CAST(total_price_after_vat AS NUMERIC)     AS line_total_incl_vat,

    CAST(created_at AS TIMESTAMP)              AS created_at,
    CAST(updated_at AS TIMESTAMP)              AS updated_at,
    CAST(order_updated_at AS TIMESTAMP)        AS order_updated_at
FROM {{raw.traede.order_line}}
