-- core.amazon_mws.monthly_returns_analysis
-- Monthly Returns Analysis. Extracts a monthly returns analysis for Amazon
-- integration. It calculates various metrics such as total returns, total refunded
-- amount, in-policy returns, out-of-policy returns, prime returns, and non-prime
-- returns. Additionally, it provides information on return reasons and their
-- respective counts. The results are sorted by month and reason count in descending
-- order.
--
-- From the weld.app template library. Not reconciled against Amazon Seller Central;
-- check the output against the source before relying on it.

with
    MonthlyReturns as (
        select
            date_trunc(cast(return_request_date as date), month) as month
          , count(distinct order_id) as TotalReturns
          , sum(refunded_amount) as TotalRefundedAmount
          , countif(in_policy) as InPolicyReturns
          , countif(not in_policy) as OutOfPolicyReturns
          , sum(
                case
                    when is_prime then 1
                    else 0
                end
            ) as PrimeReturns
          , sum(
                case
                    when not is_prime then 1
                    else 0
                end
            ) as NonPrimeReturns
        from
            {{raw.amazon_selling_api_oauth.returns_by_return_date_report}}
        group by
            month
    )
  , ReturnReasons as (
        select
            date_trunc(cast(return_request_date as date), month) as month
          , return_reason
          , count(distinct order_id) as ReasonCount
        from
         	 {{raw.amazon_selling_api_oauth.returns_by_return_date_report}}
        group by
            month
          , return_reason
    )
select
    m.Month
  , m.TotalReturns
  , m.TotalRefundedAmount
  , m.InPolicyReturns
  , m.OutOfPolicyReturns
  , m.PrimeReturns
  , m.NonPrimeReturns
  , r.return_reason
  , r.ReasonCount
from
    MonthlyReturns m
    left join ReturnReasons r on m.Month = r.Month
order by
    m.Month desc
  , r.ReasonCount desc
