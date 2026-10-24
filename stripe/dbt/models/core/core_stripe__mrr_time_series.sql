-- core_stripe__mrr_time_series
-- Create time series for each customer. This SQL model captures the monthly
-- recurring revenue (MRR) trend for each customer, including the change in MRR, and
-- provides a rank based on the MRR. It also considers the customer's subscription
-- status and cancellation date.
--
-- The monthly calendar starts at the earliest subscription start month in
-- the data and runs to the current month.
--
-- From the weld.app template library, corrected. Not reconciled against
-- Stripe; check the output against the source before relying on it.

with
    time_series as (
        select
            month
        from
            unnest (
                generate_date_array(
                    (select min(start_date_month) from {{ ref('core_stripe__mrr_active_subscriptions') }})
                  , current_date
                  , interval 1 month
                )
            ) as month
    )
  , time_series_customer as (
        select
            *
        from
            (
                select distinct
                    (customer_id) customer_id
                  , month
                from
                    {{ ref('core_stripe__mrr_active_subscriptions') }}
                    cross join time_series
                order by
                    customer_id
                  , month
            )
    )
  , time_series_revenue as (
        select
            c.customer_id
          , month
          , start_date_month
          , first_value(canceled_at ignore nulls) over (
                partition by
                    c.customer_id
                order by
                    month asc
            ) canceled_at
          , monthly_amount_eur_after_discount
          , first_value(status ignore nulls) over (
                partition by
                    c.customer_id
                order by
                    month asc
            ) status
          , last_value(monthly_amount_eur_after_discount ignore nulls) over (
                partition by
                    c.customer_id
                order by
                    month asc
            ) mrr
        from
            time_series_customer c
            left join {{ ref('core_stripe__mrr_active_subscriptions') }} r on c.customer_id = r.customer_id
            and c.month = r.start_date_month
        order by
            customer_id
          , month asc
    )
select
    *
  , case
        when mrr - lag(mrr) over (
            partition by
                customer_id
            order by
                month asc
        ) is null then mrr
        else mrr - lag(mrr) over (
            partition by
                customer_id
            order by
                month asc
        )
    end mrr_change
  , row_number() over (
        partition by
            customer_id
        order by
            month asc
    ) mrr_rank_asc
  , row_number() over (
        partition by
            customer_id
        order by
            month desc
    ) mrr_rank_desc
from
    time_series_revenue
where mrr is not null
    and (
        canceled_at is null
        or month <= canceled_at
    )
order by
    customer_id
  , month asc
