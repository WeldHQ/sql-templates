-- core_amazon_seller__sales_over_time - recreates Amazon's Business Reports "Sales and
-- Traffic by date" page, and puts all three revenue definitions on one row.
--
-- Grain: day x seller x marketplace. Currency: the marketplace's own.
-- Depends on: stg_amazon_seller__sales_and_traffic_by_date
--
-- WHY START FROM AMAZON'S OWN REPORT RATHER THAN THE ORDER DATA. Because this is
-- the number your team already quotes. Seller Central's dashboard shows
-- `ordered_product_sales`, so that is the figure in the weekly update and in the
-- board deck, and a model that computes its own from order lines will be close but
-- never equal - Amazon applies cancellation and pending-order logic it does not
-- document. Take the reported number as given here, and use
-- core_amazon_seller__product_sales_over_time when you need it split by ASIN.
--
-- THE THREE REVENUE NUMBERS, and why they never match:
--
--   ordered_product_sales   what customers ordered, on the ORDER date.
--                           Amazon's headline. Includes orders not yet shipped,
--                           excludes tax, net of cancellations.
--   shipped_product_sales   what actually shipped, on the SHIP date. Lags ordered
--                           by fulfilment time, so a fast-growing month always
--                           looks smaller here.
--   deposits                what Amazon paid you, on the SETTLEMENT date. Net of
--                           every fee. Lives in core_amazon_seller__settlement_ledger
--                           because it comes from a different report entirely.
--
-- All three are correct. They are different questions - demand, fulfilment, and
-- cash - and the argument about which is "the real revenue number" only ends when
-- all three are on the same row, which is what this model is for.

{{ config(materialized='table') }}

SELECT
    d.date,
    d.amazon_seller,
    d.marketplace,
    d.currency,

    -- Demand: the Seller Central headline.
    d.ordered_product_sales,
    d.units_ordered,
    d.total_order_items,
    d.average_selling_price,
    d.average_units_per_order_item,

    -- Fulfilment: same money, counted when it left the warehouse.
    d.shipped_product_sales,
    d.units_shipped,
    d.orders_shipped,

    -- The gap between the two, which is the honest way to present them. Positive
    -- means you sold faster than you shipped that day. Over a month it should trend
    -- to roughly zero; a persistent gap is a fulfilment backlog, not an accounting
    -- artefact.
    d.ordered_product_sales - d.shipped_product_sales   AS ordered_minus_shipped_sales,
    d.units_ordered - d.units_shipped                   AS ordered_minus_shipped_units,

    -- Returns and claims. Amazon reports units_refunded on the REFUND date, so this
    -- column and units_ordered on the same row describe different cohorts - the
    -- refund rate below is Amazon's own same-day ratio, not a cohort return rate.
    -- For that, use core_amazon_seller__product_sales_over_time, which keeps the
    -- original order date alongside the return date.
    d.units_refunded,
    d.refund_rate,
    d.claims_granted,
    d.claims_amount,

    -- Traffic and conversion, at day grain. Sessions are visits, page views are
    -- pages within them, so page_views >= sessions always.
    d.sessions,
    d.browser_sessions,
    d.mobile_app_sessions,
    d.page_views,
    d.browser_page_views,
    d.mobile_app_page_views,

    -- Unit session percentage IS the conversion rate, under Amazon's name for it:
    -- units ordered divided by sessions. It is the single most useful number in the
    -- report and the most commonly recomputed wrongly, because dividing by
    -- page_views instead of sessions gives a plausible number that is far too low.
    d.unit_session_percentage,
    d.order_item_session_percentage,

    -- Buy Box percentage is the share of page views where YOU held the featured
    -- offer. Below ~90% on your own listings you are losing sales to resellers, and
    -- no amount of ad spend fixes it.
    d.buy_box_percentage,
    d.average_offer_count,
    d.average_parent_items,

    d.feedback_received,
    d.negative_feedback_received,
    d.received_negative_feedback_rate
FROM {{ ref('stg_amazon_seller__sales_and_traffic_by_date') }} d
