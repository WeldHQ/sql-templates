-- core_amazon_mws__monthly_inventory_report
-- Monthly Inventory Reports. Extracts monthly inventory reports for Amazon
-- integration. It retrieves data from the Amazon Selling API to calculate various
-- metrics such as total items listed, total fulfillable quantity, total damaged
-- items, expired items, total unfulfillable quantity, items in transit, and items
-- receiving. The results are ordered by month in descending order.
--
-- From the weld.app template library. Not reconciled against Amazon Seller Central;
-- check the output against the source before relying on it.

with
    MonthlyInventory as (
        select
            date_trunc(cast(last_updated_time as timestamp), month) as month
          , sum(total_quantity) as TotalItemsListed
          , sum(fulfillable_quantity) as TotalFulfillableQuantity
          , sum(
                carrier_damaged_quantity + customer_damaged_quantity + defective_quantity + distributor_damaged_quantity + expired_quantity + warehouse_damaged_quantity
            ) as TotalDamaged
          , sum(expired_quantity) as ExpiredItems
          , sum(total_unfulfillable_quantity) as TotalUnfulfillableQuantity
          , sum(inbound_shipped_quantity) as ItemsInTransit
          , sum(inbound_receiving_quantity) as ItemsReceiving
        from
            {{ source('amazon_selling_api_oauth', 'fba_inventory_summary') }}
        group by
            month
    )
select
    month
  , TotalItemsListed
  , TotalFulfillableQuantity
  , TotalDamaged
  , ExpiredItems
  , TotalUnfulfillableQuantity
  , ItemsInTransit
  , ItemsReceiving
from
    MonthlyInventory
order by
    month desc
