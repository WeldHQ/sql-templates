-- core_amazon_mws__monthly_sales_performance_report
-- Monthly Sales Performance Reports. Extracts monthly sales performance reports for
-- Amazon integration. It calculates the total sales amount, number of orders, and
-- total items sold for each month. Additionally, it calculates the average order
-- value by dividing the total sales amount by the number of orders. The results are
-- ordered in descending order by month.
--
-- From the weld.app template library. Not reconciled against Amazon Seller Central;
-- check the output against the source before relying on it.

with
    MonthlySales as (
        select
            date_trunc(cast(PurchaseDate as date), month) month
          , sum(OrderTotal_Amount) as TotalSalesAmount
          , count(distinct AmazonOrderId) as NumberOfOrders
          , sum(NumberOfItemsShipped + NumberOfItemsUnshipped) as TotalItemsSold
        from
            {{ source('amazon_selling_api_oauth', 'orders') }}
        group by
         
           month
    )
select
    month
  , TotalSalesAmount
  , NumberOfOrders
  , TotalItemsSold
  , TotalSalesAmount / NumberOfOrders as AverageOrderValue
from
    MonthlySales
order by
    month desc
