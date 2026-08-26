-- staging.amazon_seller.fba_inventory
-- Thin wrapper over raw `fba_inventory_summary`. Casts, renames, groups the ~15
-- quantity buckets into four that mean something. No other logic.
--
-- CURRENT STATE, NOT HISTORY. This report is a snapshot: it tells you what is in
-- Amazon's warehouses now, and Amazon does not keep yesterday's. To trend stock
-- cover or measure how long units sat, enable Weld's history tables on this stream
-- (Data Source > the stream > History tables) and read
-- `fba_inventory_summary__history` instead - there is no way to reconstruct it
-- afterwards.

SELECT
    'seller_1'                                                  AS amazon_seller,
    UPPER(NULLIF(TRIM(CAST(marketplace_id AS STRING)), ''))     AS marketplace,
    CAST(seller_sku AS STRING)                                  AS sku,
    UPPER(NULLIF(TRIM(CAST(asin AS STRING)), ''))               AS asin,
    CAST(fn_sku AS STRING)                                      AS fnsku,
    CAST(product_name AS STRING)                                AS product_name,
    LOWER(CAST(condition AS STRING))                            AS condition,
    CAST(last_updated_time AS TIMESTAMP)                        AS last_updated_at,

    -- Sellable and available to a customer right now.
    CAST(fulfillable_quantity AS INT64)                         AS fulfillable_units,

    -- In transit to or being processed by Amazon. Counts toward cover, not toward
    -- what you can sell today.
    CAST(inbound_working_quantity AS INT64)
      + CAST(inbound_shipped_quantity AS INT64)
      + CAST(inbound_receiving_quantity AS INT64)               AS inbound_units,

    -- Reserved: allocated to an order, moving between centres, or being processed.
    -- Physically yours, not sellable.
    CAST(total_reserved_quantity AS INT64)                      AS reserved_units,

    -- Written off in all but name. Amazon will not sell these and will eventually
    -- charge you to dispose of them.
    CAST(total_unfulfillable_quantity AS INT64)                 AS unfulfillable_units,

    CAST(total_quantity AS INT64)                               AS total_units,

    -- The unfulfillable breakdown, because the reason decides the remedy: damage in
    -- Amazon's custody is a reimbursement claim, customer damage and expiry are not.
    CAST(warehouse_damaged_quantity AS INT64)                   AS warehouse_damaged_units,
    CAST(carrier_damaged_quantity AS INT64)                     AS carrier_damaged_units,
    CAST(customer_damaged_quantity AS INT64)                    AS customer_damaged_units,
    CAST(distributor_damaged_quantity AS INT64)                 AS distributor_damaged_units,
    CAST(defective_quantity AS INT64)                           AS defective_units,
    CAST(expired_quantity AS INT64)                             AS expired_units,

    CAST(pending_customer_order_quantity AS INT64)              AS pending_customer_order_units,
    CAST(total_researching_quantity AS INT64)                   AS researching_units
FROM {{raw.amazon_seller_central.fba_inventory_summary}}
