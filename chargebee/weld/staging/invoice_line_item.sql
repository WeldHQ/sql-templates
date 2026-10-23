-- staging.chargebee.invoice_line_item
-- Thin wrapper over raw `invoice_line_item`. One row per invoice line. Casts,
-- renames and converts minor units to major units. No other logic.
--
-- The line table carries no currency of its own, so the currency and the
-- minor-unit divisor come from the parent invoice in staging.chargebee.invoice.
-- Lines whose invoice was deleted get NULL money and are dropped in core.
--
-- `amount` is quantity x unit price BEFORE discounts and tax. `discount_amount`
-- is the line's total discount (item-level plus its share of invoice-level
-- discounts), so `net_amount` = amount - discount_amount is the line's share of
-- the invoice sub_total. tests/assert_chargebee__lines_tie_to_invoice_sub_total.sql checks
-- that identity.
--
-- invoice_line_item carries no subscription_id, so a line is tied to a
-- subscription only through its invoice, and only when the invoice covers a
-- single subscription.

WITH source AS (
    SELECT *
    FROM {{raw.chargebee.invoice_line_item}}
    QUALIFY ROW_NUMBER() OVER (PARTITION BY id ORDER BY _weld_synced DESC) = 1
)

SELECT
    CAST(l.id AS STRING)                                        AS line_item_id,
    CAST(l.invoice_id AS STRING)                                AS invoice_id,
    CAST(l.customer_id AS STRING)                               AS customer_id,

    -- plan_item_price, addon_item_price, charge_item_price on Product Catalog 2.0;
    -- plan, addon, plan_setup, adhoc on the legacy catalog.
    LOWER(CAST(l.entity_type AS STRING))                        AS entity_type,
    CAST(l.entity_id AS STRING)                                 AS entity_id,
    CAST(l.description AS STRING)                               AS description,
    LOWER(CAST(l.pricing_model AS STRING))                      AS pricing_model,
    CAST(l.quantity AS INT64)                                   AS quantity,

    -- Service period. date_to is the start of the next period, not the last
    -- second of this one, so a monthly line runs from 1 March to 1 April.
    CAST(l.date_from AS TIMESTAMP)                              AS service_from,
    CAST(l.date_to AS TIMESTAMP)                                AS service_to,

    i.currency                                                  AS currency,
    i.minor_unit_divisor                                        AS minor_unit_divisor,
    CAST(l.unit_amount AS NUMERIC) / i.minor_unit_divisor       AS unit_amount,
    CAST(l.amount AS NUMERIC) / i.minor_unit_divisor            AS amount,
    CAST(COALESCE(l.discount_amount, 0) AS NUMERIC)
        / i.minor_unit_divisor                                  AS discount_amount,
    CAST(COALESCE(l.item_level_discount_amount, 0) AS NUMERIC)
        / i.minor_unit_divisor                                  AS item_level_discount_amount,
    CAST(COALESCE(l.tax_amount, 0) AS NUMERIC) / i.minor_unit_divisor AS tax_amount,
    CAST(l.amount - COALESCE(l.discount_amount, 0) AS NUMERIC)
        / i.minor_unit_divisor                                  AS net_amount
FROM source l
LEFT JOIN {{staging.chargebee.invoice}} i
       ON i.invoice_id = CAST(l.invoice_id AS STRING)
