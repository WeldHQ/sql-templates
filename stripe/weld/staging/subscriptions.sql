-- staging.stripe.subscriptions
-- Get all subscriptions. Extracts a comprehensive overview of Stripe subscriptions.
-- This helps in understanding the status and duration of various subscriptions tied
-- to different customers.
--
-- From the weld.app template library. Not reconciled against Stripe;
-- check the output against the source before relying on it.

select
    id,
    customer_id,
    start_date,
    canceled_at,
    id as subscription_id,
    status
from
    {{raw.stripe.subscription}}
