-- core.amazon_mws.monthly_financial_analysis
-- Monthly Financial Analysis. Generates a monthly financial analysis for Amazon
-- integration. It calculates the gross revenue, refunds, net revenue, average item
-- price, average promotion discount, average shipping price, and average shipping
-- tax. The analysis is based on data from the settlement report and orders by last
-- updated date report. The results are sorted in descending order by month.
--
-- From the weld.app template library. Not reconciled against Amazon Seller Central;
-- check the output against the source before relying on it.

with
    MonthlyRevenue as (
        select
            date_trunc(
                cast(
                    format_date('%Y-%m-%d', parse_date('%d.%m.%Y', posted_date)) as date
                )
              , month
            ) month
          , sum(
                case
                    when amount_type = 'ItemPrice' then amount
                    else 0
                end
            ) as GrossRevenue
          , sum(
                case
                    when amount_type = 'Refund' then amount
                    else 0
                end
            ) as Refunds
          , avg(amount) as AverageItemPrice
        from
            {{raw.amazon_selling_api_oauth.settlement_report}}
        group by
            month
    )
  , OrderDiscounts as (
        select
            date_trunc(cast(purchase_date as date), month) month
          , avg(item_promotion_discount) as AveragePromotionDiscount
          , avg(shipping_price) as AverageShippingPrice
          , avg(shipping_tax) as AverageShippingTax
        from
            {{raw.amazon_selling_api_oauth.orders_by_last_updated_date_report}}
        group by
            month
    )
select
    r.Month
  , r.GrossRevenue
  , r.Refunds
  , r.GrossRevenue - r.Refunds as NetRevenue
  , r.AverageItemPrice
  , d.AveragePromotionDiscount
  , d.AverageShippingPrice
  , d.AverageShippingTax
from
    MonthlyRevenue r
    join OrderDiscounts d on r.Month = d.Month
order by
    r.Month desc
