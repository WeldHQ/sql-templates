-- core_amazon_mws__monthly_shipping_and_delivery_report
-- Monthly Shipping and Delivery Reports. Generates a monthly shipping and delivery
-- report for Amazon integration. It calculates various metrics such as the number
-- of orders, total items shipped and unshipped, average days to ship, and the count
-- of premium and regular orders. It also includes information on different shipping
-- service levels and the number of orders for each level. The final result is
-- sorted by month and shipping service level.
--
-- From the weld.app template library. Not reconciled against Amazon Seller Central;
-- check the output against the source before relying on it.

with
    MonthlyShippingPerformance as (
        select
            date_trunc(cast(PurchaseDate as date), month) month
          , count(distinct AmazonOrderId) as NumberOfOrders
          , sum(NumberOfItemsShipped) as TotalItemsShipped
          , sum(NumberOfItemsUnshipped) as TotalItemsUnshipped
          , avg(
                timestamp_diff(LatestShipDate, EarliestShipDate, day)
            ) as AvgDaysToShip
          , sum(
                case
                    when IsPremiumOrder then 1
                    else 0
                end
            ) as PremiumOrders
          , sum(
                case
                    when not IsPremiumOrder then 1
                    else 0
                end
            ) as RegularOrders
        from
            {{ source('amazon_selling_api_oauth', 'orders') }}
        group by
            month
    )
  , ShippingServiceLevels as (
        select
            date_trunc(cast(PurchaseDate as date), month) month
          , ShipServiceLevel
          , count(distinct AmazonOrderId) as ServiceLevelOrders
        from
            {{ source('amazon_selling_api_oauth', 'orders') }}
        group by
            month
          , ShipServiceLevel
    )
select
    m.Month
  , m.NumberOfOrders
  , m.TotalItemsShipped
  , m.TotalItemsUnshipped
  , m.AvgDaysToShip
  , m.PremiumOrders
  , m.RegularOrders
  , s.ShipServiceLevel
  , s.ServiceLevelOrders
from
    MonthlyShippingPerformance m
    left join ShippingServiceLevels s on m.Month = s.Month
order by
    m.Month desc
  , s.ShipServiceLevel
