-- core_amazon_mws__monthly_order_update_tracking_report
-- Monthly Order Update Tracking Report. Extracts a monthly order update tracking
-- report for Amazon integration. It retrieves data from the
-- "orders_by_last_updated_date_report" table and calculates various metrics such as
-- total orders updated, total updates, average price updated, status breakdown, and
-- channel breakdown. The results are sorted by month, status count, and channel
-- count in descending order.
--
-- From the weld.app template library. Not reconciled against Amazon Seller Central;
-- check the output against the source before relying on it.

with
    MonthlyOrderUpdates as (
        select
            date_trunc(cast(last_updated_date as date), month) as month
          , count(distinct amazon_order_id) as TotalOrdersUpdated
          , count(amazon_order_id) as TotalUpdates
          , avg(item_price) as AveragePriceUpdated
        from
            {{ source('amazon_selling_api_oauth', 'orders_by_last_updated_date_report') }}
        group by
            month
    )
  , StatusBreakdown as (
        select
            date_trunc(cast(last_updated_date as date), month) as month
          , order_status
          , count(distinct amazon_order_id) as StatusCount
        from
           {{ source('amazon_selling_api_oauth', 'orders_by_last_updated_date_report') }}
        group by
            month
          , order_status
    )
  , ChannelBreakdown as (
        select
            date_trunc(cast(last_updated_date as date), month) as month
          , order_channel
          , count(distinct amazon_order_id) as ChannelCount
        from
             {{ source('amazon_selling_api_oauth', 'orders_by_last_updated_date_report') }}
        group by
            month
          , order_channel
    )
select
    m.Month
  , m.TotalOrdersUpdated
  , m.TotalUpdates
  , m.AveragePriceUpdated
  , s.order_status
  , s.StatusCount
  , c.order_channel
  , c.ChannelCount
from
    MonthlyOrderUpdates m
    left join StatusBreakdown s on m.Month = s.Month
    left join ChannelBreakdown c on m.Month = c.Month
order by
    m.Month desc
  , s.StatusCount desc
  , c.ChannelCount desc
