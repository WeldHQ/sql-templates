-- amazon_vendor_inventory_health - the operational scorecard Amazon grades you on,
-- with sales velocity attached so the numbers mean something.
--
-- Grain: day x vendor x marketplace x distributor view x selling program x ASIN.
-- Currency: the marketplace's.
-- Depends on: staging.amazon_vendor.inventory, .sales
--
-- WHAT MAKES THIS DIFFERENT FROM A SELLER INVENTORY MODEL. You do not control this
-- inventory - Amazon bought it and holds it. What you control is whether you confirm
-- and ship the purchase orders Amazon sends, and how fast. So the metrics that matter
-- are about the SUPPLY RELATIONSHIP, not about stock levels:
--
--   vendor_confirmation_rate  yours to fix. Amazon's read on whether you are
--                             dependable supply, and it feeds how much it orders next.
--   average_vendor_lead_time  yours to fix. Long lead times make Amazon carry more
--                             safety stock, which it accounts for by ordering less.
--   sell_through_rate         shared. Slow turns lead to smaller POs.
--   unhealthy_inventory       Amazon's problem that becomes yours. Excess stock is
--                             what precedes a markdown request or a return-to-vendor.
--
-- The ratios below put those against actual sales, which is the part Vendor Central
-- will not do for you: an ASIN with 400 units of unhealthy inventory is either two
-- weeks of cover or two years of it, and the report alone cannot tell you which.

WITH velocity AS (
    SELECT
        amazon_vendor, marketplace, distributor_view, selling_program, asin,
        SUM(shipped_units)                     AS shipped_units_30d,
        SAFE_DIVIDE(SUM(shipped_units), 30.0)  AS shipped_units_per_day
    FROM {{staging.amazon_vendor.sales}}
    WHERE date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
    GROUP BY 1, 2, 3, 4, 5
)

SELECT
    i.date,
    i.amazon_vendor,
    i.marketplace,
    i.distributor_view,
    i.selling_program,
    i.asin,
    i.currency,

    -- Your supply performance.
    i.vendor_confirmation_rate,
    i.average_vendor_lead_time_days,
    i.receive_fill_rate,

    -- The purchase-order pipeline. Negative open units mean you over-shipped against
    -- a PO; that is a real state, not bad data.
    i.open_purchase_order_units,
    i.net_received_inventory_units,
    ROUND(i.net_received_inventory_cost, 2)         AS net_received_inventory_cost,

    -- What Amazon is holding.
    i.sellable_on_hand_inventory_units,
    ROUND(i.sellable_on_hand_inventory_cost, 2)     AS sellable_on_hand_inventory_cost,
    i.unsellable_on_hand_inventory_units,
    ROUND(i.unsellable_on_hand_inventory_cost, 2)   AS unsellable_on_hand_inventory_cost,
    i.aged_90_plus_days_sellable_inventory_units,
    ROUND(i.aged_90_plus_days_sellable_inventory_cost, 2) AS aged_90_plus_days_sellable_inventory_cost,
    i.unhealthy_inventory_units,
    ROUND(i.unhealthy_inventory_cost, 2)            AS unhealthy_inventory_cost,

    i.sell_through_rate,
    i.unfilled_customer_ordered_units,

    -- Aggregate-only in Amazon's report; NULL at ASIN grain by design.
    i.procurable_product_out_of_stock_rate,
    i.uft,

    -- Velocity, and the ratios that turn a unit count into a decision.
    COALESCE(v.shipped_units_30d, 0)                AS shipped_units_30d,
    ROUND(COALESCE(v.shipped_units_per_day, 0), 2)  AS shipped_units_per_day,

    -- Days of cover on what Amazon holds sellable. NULL rather than a huge number for
    -- an ASIN with no shipments - "unknown" is honest, and infinity sorts to the top
    -- of a well-stocked report and stays there.
    ROUND(SAFE_DIVIDE(i.sellable_on_hand_inventory_units,
                      NULLIF(v.shipped_units_per_day, 0)), 1) AS days_of_cover,

    -- How much of what Amazon holds is stale, and what share of the value is at risk.
    ROUND(SAFE_DIVIDE(i.aged_90_plus_days_sellable_inventory_units,
                      NULLIF(i.sellable_on_hand_inventory_units, 0)), 4) AS aged_inventory_share,
    ROUND(SAFE_DIVIDE(i.unhealthy_inventory_cost,
                      NULLIF(i.sellable_on_hand_inventory_cost, 0)), 4)  AS unhealthy_value_share,

    -- Unhealthy inventory expressed in weeks of demand. The number to bring to a
    -- business review: "eleven weeks of cover" is a conversation, "3,400 units" is not.
    ROUND(SAFE_DIVIDE(i.unhealthy_inventory_units,
                      NULLIF(v.shipped_units_per_day * 7, 0)), 1) AS unhealthy_weeks_of_cover,

    -- Flags. Thresholds are the ones Amazon's own vendor scorecards use; adjust to
    -- your category rather than treating them as universal.
    i.vendor_confirmation_rate < 0.95                            AS is_confirmation_rate_at_risk,
    i.sellable_on_hand_inventory_units = 0
        AND COALESCE(v.shipped_units_per_day, 0) > 0             AS is_out_of_stock_at_amazon,
    i.unfilled_customer_ordered_units > 0                        AS has_unfilled_customer_orders
FROM {{staging.amazon_vendor.inventory}} i
LEFT JOIN velocity v
       ON  v.amazon_vendor    = i.amazon_vendor
       AND v.marketplace      = i.marketplace
       AND v.distributor_view = i.distributor_view
       AND v.selling_program  = i.selling_program
       AND v.asin             = i.asin
