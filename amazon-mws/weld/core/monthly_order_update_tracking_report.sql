-- core.amazon_mws.monthly_order_update_tracking_report
-- Monthly Order Update Tracking Report. Extracts a monthly order update tracking
-- report for Amazon integration. It retrieves data from the
-- "orders_by_last_updated_date_report" table and counts the orders updated in
-- each month, broken down by order status and sales channel.
--
-- Grain: month x order status x order channel, by last-updated date. Each row
-- counts the distinct orders updated in that month with that status and
-- channel, the report rows behind them, and their average item price. An order
-- that changed status within a month appears under each status it had, so
-- add up orders_updated across statuses with care.
--
-- From the weld.app template library, corrected. Not reconciled against Amazon
-- Seller Central; check the output against the source before relying on it.

select
    date_trunc(cast(last_updated_date as date), month) as month
  , order_status
  , order_channel
  , count(distinct amazon_order_id) as orders_updated
  , count(*) as updates
  , avg(item_price) as average_item_price
from
    {{raw.amazon_selling_api_oauth.orders_by_last_updated_date_report}}
group by
    month
  , order_status
  , order_channel
order by
    month desc
  , orders_updated desc
