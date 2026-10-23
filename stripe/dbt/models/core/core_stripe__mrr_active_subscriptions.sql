-- core_stripe__mrr_active_subscriptions
-- Identify active subscriptions and sum revenue. This SQL model fetches the monthly
-- revenue per subscription and applies discounts to provide a net monthly amount.
-- It then identifies if a subscription is active or canceled based on the status.
--
-- Grain: customer x month a subscription started. status and canceled_at
-- describe the customer (active if any subscription is still live), so each
-- customer has one row per start month for the time series to join on.
--
-- From the weld.app template library, corrected. Not reconciled against
-- Stripe; check the output against the source before relying on it.

with
revenue_per_subscription as (
    select
        customer_id,
        cast(date_trunc(start_date, month) as date) as start_date_month,
        cast(date_trunc(canceled_at, month) as date) as canceled_at,
        max(amount_off) as amount_off,
        status,
        sum(monthly_amount_eur) as monthly_amount_eur,
        sum(monthly_amount_eur) - ifnull(max(amount_off), 0) as monthly_amount_eur_after_discount
    from
        {{ ref('core_stripe__mrr_normalization') }}
    group by
        customer_id,
        start_date_month,
        canceled_at,
        status
),
active_subscriptions as (
    select
        customer_id,
        max(status) as status
    from
        revenue_per_subscription
    where
        status <> 'canceled'
    group by
        customer_id
),
cancelled_subscriptions as (
    select
        customer_id,
        max(canceled_at) as canceled_at,
        max(status) as status
    from
        revenue_per_subscription
    where
        status = 'canceled'
    group by
        customer_id
)
select
    r.customer_id,
    coalesce(s.status, c.status) as status,
    r.start_date_month,
    case
        when coalesce(s.status, c.status) = 'canceled' then c.canceled_at
        else null
    end as canceled_at,
    cast(
        round(sum(monthly_amount_eur_after_discount), 0)
    as int) as monthly_amount_eur_after_discount
from
    revenue_per_subscription r
left join active_subscriptions s on r.customer_id = s.customer_id
left join cancelled_subscriptions c on r.customer_id = c.customer_id
group by
    1,
    2,
    3,
    4
order by
    customer_id
