-- core_amazon_seller__inventory_health - what is in Amazon's warehouses, how long it lasts,
-- and how much of it is dead.
--
-- Grain: seller x marketplace x SKU. Point in time - see the note below.
-- Depends on: stg_amazon_seller__fba_inventory, .listings,
--             core_amazon_seller__product_sales_over_time
--
-- POINT IN TIME, NOT A TIME SERIES. The FBA inventory report is a snapshot and Amazon
-- does not retain yesterday's, so this model describes now. It carries no date column
-- for that reason: a date would imply history that does not exist, and someone would
-- eventually GROUP BY it. To trend cover or ageing, enable Weld history tables on the
-- fba_inventory_summary stream and build the equivalent over
-- `fba_inventory_summary__history` - there is no way to reconstruct it later.
--
-- The velocity window is the last 30 days of SALE rows. Short enough to reflect
-- current demand, long enough to survive a slow week. For seasonal catalogues, 30
-- days across a seasonal boundary will mislead - widen it or compare against the same
-- weeks last year.

{{ config(materialized='table') }}

WITH velocity AS (
    SELECT
        amazon_seller,
        marketplace,
        sku,
        SUM(quantity)                              AS units_30d,
        SAFE_DIVIDE(SUM(quantity), 30.0)           AS units_per_day
    FROM {{ ref('core_amazon_seller__product_sales_over_time') }}
    WHERE report_row_type = 'SALE'
      AND date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
    GROUP BY 1, 2, 3
)

SELECT
    i.amazon_seller,
    i.marketplace,
    i.sku,
    i.asin,
    i.fnsku,
    COALESCE(l.product_name, i.product_name) AS product_name,
    l.listing_status,
    i.condition,
    i.last_updated_at,

    i.fulfillable_units,
    i.inbound_units,
    i.reserved_units,
    i.unfulfillable_units,
    i.total_units,

    COALESCE(v.units_30d, 0)                 AS units_sold_30d,
    ROUND(COALESCE(v.units_per_day, 0), 2)   AS units_per_day,

    -- Days of cover on sellable stock only. NULL, not infinity, for a SKU with no
    -- sales in the window: "unknown" is the truth, and a huge number would sort to
    -- the top of a "well stocked" report and stay there.
    ROUND(SAFE_DIVIDE(i.fulfillable_units, NULLIF(v.units_per_day, 0)), 1) AS days_of_cover,

    -- Cover including inbound, which is the number that decides whether to reorder
    -- today. Inbound is not sellable yet but it is committed.
    ROUND(SAFE_DIVIDE(i.fulfillable_units + i.inbound_units, NULLIF(v.units_per_day, 0)), 1) AS days_of_cover_incl_inbound,

    -- Dead stock. Amazon charges storage on unfulfillable units and will eventually
    -- charge you to remove them, so this is a cost accruing right now.
    ROUND(SAFE_DIVIDE(i.unfulfillable_units, NULLIF(i.total_units, 0)), 4) AS unfulfillable_share,

    -- The reason matters because the remedy differs. Damage in Amazon's custody -
    -- warehouse and carrier - is reimbursable; open a case. Customer damage, defects
    -- and expiry are yours.
    i.warehouse_damaged_units + i.carrier_damaged_units AS amazon_caused_damage_units,
    i.customer_damaged_units + i.defective_units + i.expired_units + i.distributor_damaged_units AS seller_caused_damage_units,

    i.pending_customer_order_units,
    i.researching_units,

    -- Two flags worth alerting on, both defined so they cannot fire for a SKU that
    -- simply is not selling.
    i.fulfillable_units = 0 AND COALESCE(v.units_per_day, 0) > 0        AS is_stocked_out,
    SAFE_DIVIDE(i.fulfillable_units, NULLIF(v.units_per_day, 0)) < 14   AS is_low_cover
FROM {{ ref('stg_amazon_seller__fba_inventory') }} i
LEFT JOIN {{ ref('stg_amazon_seller__listings') }} l
       ON  l.amazon_seller = i.amazon_seller
       AND l.marketplace   = i.marketplace
       AND l.sku           = i.sku
LEFT JOIN velocity v
       ON  v.amazon_seller = i.amazon_seller
       AND v.marketplace   = i.marketplace
       AND v.sku           = i.sku
