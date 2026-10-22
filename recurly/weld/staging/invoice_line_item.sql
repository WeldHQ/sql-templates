-- staging.recurly.invoice_line_item
-- Thin wrapper over raw `invoice_line_item`. One row per line item. Casts,
-- renames, rounds money to cents. No other logic.
--
-- Weld reads line items from Recurly's site-level line item list, not from the
-- invoice payload, so invoices with many lines are complete.
--
-- SIGNS. A `charge` line is positive, a `credit` line is negative (Recurly stores
-- a negative unit_amount on credits). A credit created from a charge keeps the
-- charge's `origin`, so the credit for the unused part of a plan on a downgrade
-- has origin `plan`, which is what lets core net it against the plan charge.
--
-- NET AMOUNT is subtotal minus discount, before tax, built here rather than read
-- from `amount` so that it does not depend on whether `amount` includes tax.
-- The discount is applied towards zero whatever sign Recurly gives it, so a
-- discounted credit shrinks in magnitude just as a discounted charge does.

SELECT
    CAST(id AS STRING)                                          AS line_item_id,
    CAST(invoice_id AS STRING)                                  AS invoice_id,
    CAST(account_id AS STRING)                                  AS account_id,
    CAST(subscription_id AS STRING)                             AS subscription_id,
    CAST(plan_id AS STRING)                                     AS plan_id,
    CAST(plan_code AS STRING)                                   AS plan_code,
    CAST(add_on_id AS STRING)                                   AS add_on_id,
    CAST(add_on_code AS STRING)                                 AS add_on_code,
    CAST(description AS STRING)                                 AS description,

    -- charge or credit
    LOWER(CAST(type AS STRING))                                 AS line_type,
    -- invoiced or pending (not yet on an invoice)
    LOWER(CAST(state AS STRING))                                AS state,
    -- plan, add_on, plan_trial, add_on_trial, setup_fee, one_time, debit,
    -- credit, carryforward, coupon, prepayment
    LOWER(CAST(origin AS STRING))                               AS origin,
    LOWER(CAST(credit_reason_code AS STRING))                   AS credit_reason_code,
    COALESCE(CAST(refund AS BOOL), FALSE)                       AS is_refund,
    CAST(proration_rate AS FLOAT64)                             AS proration_rate,
    UPPER(NULLIF(TRIM(CAST(currency AS STRING)), ''))           AS currency,
    CAST(quantity AS INT64)                                     AS quantity,

    -- Service period. end_date is the start of the next period, so a monthly
    -- line runs from 1 March to 1 April.
    CAST(start_date AS TIMESTAMP)                               AS service_from,
    CAST(end_date AS TIMESTAMP)                                 AS service_to,
    CAST(created_at AS TIMESTAMP)                               AS created_at,

    ROUND(CAST(unit_amount AS NUMERIC), 2)                      AS unit_amount,
    ROUND(CAST(subtotal AS NUMERIC), 2)                         AS subtotal,
    ROUND(CAST(COALESCE(discount, 0) AS NUMERIC), 2)            AS discount,
    ROUND(CAST(COALESCE(tax, 0) AS NUMERIC), 2)                 AS tax,
    ROUND(CAST(amount AS NUMERIC), 2)                           AS amount,
    ROUND(CAST(subtotal AS NUMERIC), 2)
      - SIGN(ROUND(CAST(subtotal AS NUMERIC), 2))
        * ABS(ROUND(CAST(COALESCE(discount, 0) AS NUMERIC), 2)) AS net_amount
FROM {{raw.recurly.invoice_line_item}}
QUALIFY ROW_NUMBER() OVER (PARTITION BY id ORDER BY _weld_synced DESC) = 1
