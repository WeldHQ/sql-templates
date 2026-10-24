-- core.recurly.recurring_revenue_lines
-- Every billed plan and add-on charge, and every credit against one, normalised
-- to a monthly amount over the service period it covers. The input to the MRR
-- models.
--
-- Grain: one row per invoiced line item with origin `plan` or `add_on` and a
-- service period.
-- Currency: the line's own currency, in major units. Never summed across
-- currencies anywhere in this library.
--
-- WHY MRR IS BUILT FROM LINE ITEMS AND NOT FROM SUBSCRIPTIONS. The `subscription`
-- table is current state: it tells you what a subscription costs today and
-- nothing about last March. `subscription_history` only holds versions captured
-- since the stream was switched on. Line items are an immutable record of what
-- was billed for which period, so they reproduce any month back to the start of
-- the Recurly site, and they pick up upgrades and downgrades through Recurly's
-- proration charges and credits.
--
-- WHAT COUNTS AS RECURRING: origin `plan` and `add_on`, on charge lines and on
-- the credit lines Recurly creates from them (a credit inherits its charge's
-- origin). Trials (`plan_trial`, `add_on_trial`), setup fees, one-time charges,
-- carryforwards and manual credits do not count. Pending lines, not yet on an
-- invoice, and lines on voided invoices are excluded. Refund credits on a plan
-- are included: a refunded period stops counting as recurring revenue.
--
-- MONTHLY NORMALISATION. monthly_amount = net_amount / period_months, where a
-- period within 3 days of a whole number of months counts as exactly that many
-- months (a 28 to 31 day period is 1 month, 365 days is 12) and anything else,
-- typically a proration, counts as days / 30.4375. Discounts are taken off, tax
-- is excluded.

WITH recurring AS (
    SELECT
        l.line_item_id,
        l.invoice_id,
        i.invoice_date,
        i.invoice_type,
        l.account_id,
        l.subscription_id,
        l.line_type,
        l.origin,
        l.plan_code,
        l.add_on_code,
        l.description,
        l.is_refund,
        l.currency,
        DATE(l.service_from)                                AS service_start,
        DATE(l.service_to)                                  AS service_end,
        DATE_DIFF(DATE(l.service_to), DATE(l.service_from), DAY) AS service_days,
        l.net_amount
    FROM {{staging.recurly.invoice_line_item}} l
    JOIN {{staging.recurly.invoice}} i
      ON i.invoice_id = l.invoice_id
    WHERE l.state = 'invoiced'
      AND i.state <> 'voided'
      AND l.origin IN ('plan', 'add_on')
      AND l.service_from IS NOT NULL
      AND l.service_to > l.service_from
      AND l.net_amount IS NOT NULL
),

normalised AS (
    SELECT
        *,
        CASE
            WHEN ROUND(service_days / 30.4375) >= 1
             AND ABS(service_days - ROUND(service_days / 30.4375) * 30.4375) <= 3
                THEN ROUND(service_days / 30.4375)
            ELSE service_days / 30.4375
        END AS period_months
    FROM recurring
    WHERE service_days > 0
)

SELECT
    line_item_id,
    invoice_id,
    invoice_date,
    invoice_type,
    account_id                                          AS customer_id,
    subscription_id,
    line_type,
    origin,
    plan_code,
    add_on_code,
    description,
    is_refund,
    currency,
    service_start,
    -- Exclusive: the first day NOT covered.
    service_end,
    service_days,
    period_months,
    net_amount,
    net_amount / CAST(period_months AS NUMERIC)         AS monthly_amount
FROM normalised
