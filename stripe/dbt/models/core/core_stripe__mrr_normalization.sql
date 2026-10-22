-- core_stripe__mrr_normalization
-- Normalize to monthly revenue. This SQL model fetches the monthly subscription
-- amounts, converts them to EUR using average monthly forex rates, and provides
-- insights into revenue streams in a standardized currency.
--
-- From the weld.app template library. Not reconciled against Stripe;
-- check the output against the source before relying on it.

with
subscription_item as (
    select
        customer_id,
        subscription_id,
        amount_off,
        start_date,
        canceled_at,
        quantity,
        amount,
        currency,
        status,
        case
            when interval_period = 'year' then ((amount / interval_count) / 12) * quantity
            else (amount / interval_count) * quantity
        end as monthly_amount
    from
        {{ ref('core_stripe__subscription_item') }}
    where
        deleted = 0
),
forex as (
    select
        avg(rate) as rate,
        currency,
        date_trunc(timestamp, month) as month
    from
        {{ source('forex_eur', 'incremental') }}
    group by
        month, currency
    order by
        month
)
select
    customer_id,
    subscription_id,
    start_date,
    canceled_at,
    amount_off,
    status,
    case
        when monthly_amount > 0 then monthly_amount / rate
        else null
    end as monthly_amount_eur
from
    subscription_item
left join forex on date_trunc(start_date, month) = forex.month
and upper(subscription_item.currency) = forex.currency
