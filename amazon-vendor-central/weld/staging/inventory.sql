-- staging.amazon_vendor.inventory
-- Thin wrapper over raw `vendor_inventory_report`. Casts, renames, de-duplicates.
-- No other logic.
--
-- THIS IS THE REPORT THAT MAKES VENDOR CENTRAL WORTH MODELLING. The sales numbers you
-- could get from a spreadsheet emailed once a week. These you could not, and they are
-- the ones your Vendor Manager quotes at you in a business review:
--
--   vendor_confirmation_rate   share of units Amazon ordered that you confirmed.
--                              Your number. Below ~95% and Amazon starts treating
--                              you as unreliable supply.
--   sell_through_rate          units shipped divided by units available. Amazon's
--                              measure of whether your inventory turns.
--   unhealthy_inventory_units  excess versus forecast demand. The precursor to a
--                              price-reduction or return-to-vendor request.
--   average_vendor_lead_time_days  submission of a PO to receipt at the FC. Directly
--                              drives how much Amazon orders next.
--   open_purchase_order_units  confirmed and not yet received. Can be NEGATIVE when
--                              you have over-shipped against a PO - not a data error.
--
-- The out-of-stock and UFT columns are populated on the aggregate rows only, so they
-- are NULL at ASIN grain. Kept rather than dropped: NULL is the honest answer, and
-- their absence at ASIN level is worth being visible.
--
-- Same overlap warning as staging.amazon_vendor.sales: distributor_view and
-- selling_program are part of the key, MANUFACTURING and SOURCING describe
-- overlapping ASIN sets, and summing across them double-counts.

SELECT
    'vendor_1'                                  AS amazon_vendor,
    marketplace,
    distributor_view,
    selling_program,
    date,
    asin,

    vendor_confirmation_rate,
    net_received_inventory_units,
    net_received_inventory_cost,
    open_purchase_order_units,
    average_vendor_lead_time_days,
    sell_through_rate,
    unfilled_customer_ordered_units,

    sellable_on_hand_inventory_units,
    sellable_on_hand_inventory_cost,
    unsellable_on_hand_inventory_units,
    unsellable_on_hand_inventory_cost,
    aged_90_plus_days_sellable_inventory_units,
    aged_90_plus_days_sellable_inventory_cost,
    unhealthy_inventory_units,
    unhealthy_inventory_cost,

    procurable_product_out_of_stock_rate,
    uft,
    receive_fill_rate,
    currency
FROM (
    SELECT
        UPPER(NULLIF(TRIM(CAST(marketplace_id AS STRING)), ''))     AS marketplace,
        UPPER(NULLIF(TRIM(CAST(distributor_view AS STRING)), ''))   AS distributor_view,
        UPPER(NULLIF(TRIM(CAST(selling_program AS STRING)), ''))    AS selling_program,
        CAST(start_date AS DATE)                                    AS date,
        UPPER(NULLIF(TRIM(CAST(asin AS STRING)), ''))               AS asin,

        CAST(vendor_confirmation_rate AS NUMERIC)                   AS vendor_confirmation_rate,
        CAST(net_received_inventory_units AS INT64)                 AS net_received_inventory_units,
        CAST(net_received_inventory_cost_amount AS NUMERIC)         AS net_received_inventory_cost,
        CAST(open_purchase_order_units AS INT64)                    AS open_purchase_order_units,
        CAST(average_vendor_lead_time_days AS NUMERIC)              AS average_vendor_lead_time_days,
        CAST(sell_through_rate AS NUMERIC)                          AS sell_through_rate,
        CAST(unfilled_customer_ordered_units AS INT64)              AS unfilled_customer_ordered_units,

        CAST(sellable_on_hand_inventory_units AS INT64)             AS sellable_on_hand_inventory_units,
        CAST(sellable_on_hand_inventory_cost_amount AS NUMERIC)     AS sellable_on_hand_inventory_cost,
        CAST(unsellable_on_hand_inventory_units AS INT64)           AS unsellable_on_hand_inventory_units,
        CAST(unsellable_on_hand_inventory_cost_amount AS NUMERIC)   AS unsellable_on_hand_inventory_cost,
        CAST(aged_90_plus_days_sellable_inventory_units AS INT64)   AS aged_90_plus_days_sellable_inventory_units,
        CAST(aged_90_plus_days_sellable_inventory_cost_amount AS NUMERIC) AS aged_90_plus_days_sellable_inventory_cost,
        CAST(unhealthy_inventory_units AS INT64)                    AS unhealthy_inventory_units,
        CAST(unhealthy_inventory_cost_amount AS NUMERIC)            AS unhealthy_inventory_cost,

        -- Aggregate-only columns. NULL at ASIN grain.
        CAST(procurable_product_out_of_stock_rate AS NUMERIC)       AS procurable_product_out_of_stock_rate,
        CAST(uft AS NUMERIC)                                        AS uft,
        CAST(receive_fill_rate AS NUMERIC)                          AS receive_fill_rate,

        UPPER(NULLIF(TRIM(CAST(sellable_on_hand_inventory_cost_currency_code AS STRING)), '')) AS currency,

        ROW_NUMBER() OVER (
            PARTITION BY marketplace_id, distributor_view, selling_program,
                         CAST(start_date AS DATE), asin
            ORDER BY _weld_synced DESC
        ) AS generation_rank
    FROM {{raw.amazon_vendor_central.vendor_inventory_report}}
)
WHERE generation_rank = 1
