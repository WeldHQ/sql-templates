-- core.stripe.subscription_item
-- Get subscription plans. Pulls an exhaustive view of Stripe subscriptions, diving
-- into associated items, the specifics of plans, discounts applied through coupons,
-- and additional metrics like the amount discounted and subscription intervals.
--
-- From the weld.app template library. Not reconciled against Stripe;
-- check the output against the source before relying on it.

select
    s.id,
    s.customer_id,
    s.start_date,
    s.canceled_at,
    s.id as subscription_id,
    s.status,
    d.coupon_id,
    c.amount_off / 100 as amount_off,
    si.price_id,
    si.quantity,
    p.amount / 100 as amount,
    p.interval_count,
    p.interval as interval_period,
    p.currency,
    case
        when date_trunc(start_date, month) <> date_trunc(canceled_at, month) then 0
        when canceled_at is null then 0
        else 1
    end as deleted
from
    {{staging.stripe.subscriptions}} s
    left join {{raw.stripe.subscription_item}} si on s.id = si.subscription_id
    left join {{raw.stripe.plan}} p on si.price_id = p.id
    left join {{raw.stripe.subscription_discount}} d on s.id = d.subscription_id
    left join {{raw.stripe.coupon}} c on d.coupon_id = c.id
