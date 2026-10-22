-- core_chargebee__recurring_revenue_lines
-- Every billed recurring charge, and every credit against one, normalised to a
-- monthly amount over the service period it covers. The input to the MRR models.
--
-- Grain: one row per invoice line or credit note line that bills a plan or an
-- add-on for a service period.
-- Currency: the document's own currency, in major units. Never summed across
-- currencies anywhere in this library.
--
-- WHY MRR IS BUILT FROM INVOICES AND NOT FROM subscription.mrr. Chargebee's
-- `subscription.mrr` is current state: it tells you what a subscription is worth
-- today and nothing about last March. Invoice lines are an immutable record of what
-- was billed for which period, so they reproduce any month in the past, survive
-- deleted subscriptions, and pick up expansion and contraction from prorations
-- without any history table.
--
-- WHAT COUNTS AS RECURRING:
--   plan_item_price, addon_item_price   Product Catalog 2.0 plans and add-ons
--   plan, addon                         the legacy catalog's equivalents
-- One-off charges (charge_item_price, adhoc, plan_setup) never count. On Product
-- Catalog 2.0 an item can also be switched out of MRR in Chargebee
-- (`item.included_in_mrr = false`); those lines are dropped. Legacy-catalog lines
-- have no item to look up and are kept.
--
-- CREDIT NOTES SUBTRACT. A downgrade or an immediate cancellation produces a credit
-- note for the unused part of the period. Its line carries that period, so adding
-- it with a negative sign cancels the old plan from the change date onwards.
-- Every non-voided credit note line on a recurring item is included, whatever the
-- reason code, so a goodwill credit for a period also lowers MRR for that period.
--
-- MONTHLY NORMALISATION. monthly_amount = net_amount / period_months, where a
-- period within 3 days of a whole number of months counts as exactly that many
-- months (a 28 to 31 day period is 1 month, 365 days is 12) and anything else,
-- typically a proration, counts as days / 30.4375. Discounts are taken off, tax
-- is excluded.

WITH invoice_lines AS (
    SELECT
        'invoice'                   AS document_type,
        l.line_item_id,
        l.invoice_id                AS document_id,
        i.invoice_date              AS document_date,
        l.customer_id,
        i.subscription_id,
        l.entity_type,
        l.entity_id,
        l.description,
        l.currency,
        DATE(l.service_from)        AS service_start,
        DATE(l.service_to)          AS service_end,
        l.net_amount
    FROM {{ ref('stg_chargebee__invoice_line_item') }} l
    JOIN {{ ref('stg_chargebee__invoice') }} i
      ON i.invoice_id = l.invoice_id
    WHERE i.status <> 'voided'
),

credit_lines AS (
    SELECT
        'credit_note'               AS document_type,
        l.line_item_id,
        l.credit_note_id            AS document_id,
        c.credit_note_date          AS document_date,
        l.customer_id,
        COALESCE(l.subscription_id, c.subscription_id) AS subscription_id,
        l.entity_type,
        l.entity_id,
        l.description,
        l.currency,
        DATE(l.service_from)        AS service_start,
        DATE(l.service_to)          AS service_end,
        -l.net_amount               AS net_amount
    FROM {{ ref('stg_chargebee__credit_note_line_item') }} l
    JOIN {{ ref('stg_chargebee__credit_note') }} c
      ON c.credit_note_id = l.credit_note_id
    WHERE c.status <> 'voided'
),

all_lines AS (
    SELECT * FROM invoice_lines
    UNION ALL
    SELECT * FROM credit_lines
),

recurring AS (
    SELECT
        a.*,
        ip.item_id,
        it.item_name,
        DATE_DIFF(a.service_end, a.service_start, DAY) AS service_days
    FROM all_lines a
    -- item_price and item are unique on their ids, so these joins cannot fan out.
    LEFT JOIN {{ ref('stg_chargebee__item_price') }} ip
           ON ip.item_price_id = a.entity_id
          AND a.entity_type IN ('plan_item_price', 'addon_item_price')
    LEFT JOIN {{ ref('stg_chargebee__item') }} it
           ON it.item_id = ip.item_id
    WHERE a.entity_type IN ('plan_item_price', 'addon_item_price', 'plan', 'addon')
      AND COALESCE(it.included_in_mrr, TRUE)
      AND a.service_start IS NOT NULL
      AND a.service_end > a.service_start
      AND a.net_amount IS NOT NULL
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
)

SELECT
    document_type,
    line_item_id,
    document_id,
    document_date,
    customer_id,
    subscription_id,
    entity_type,
    entity_id,
    item_id,
    item_name,
    description,
    currency,
    service_start,
    -- Exclusive: the first day NOT covered.
    service_end,
    service_days,
    period_months,
    net_amount,
    net_amount / CAST(period_months AS NUMERIC)     AS monthly_amount
FROM normalised
