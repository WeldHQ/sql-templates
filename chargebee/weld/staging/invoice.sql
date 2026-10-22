-- staging.chargebee.invoice
-- Thin wrapper over raw `invoice`. One row per invoice. Casts, renames, converts
-- money from minor units to major units, drops deleted invoices. No other logic.
--
-- MONEY IS STORED IN MINOR UNITS. Chargebee returns every amount as an integer in
-- the smallest unit of the invoice currency: $499.99 arrives as 49999. The
-- exception is zero-decimal currencies, which Chargebee documents as stored in
-- whole units (JPY 15 arrives as 15). The divisor below covers the zero-decimal
-- currencies Chargebee lists (JPY, KRW, XAF, XOF); if your site bills in another
-- currency without minor units, add it to the list.
--
-- Every amount stays in the invoice's own currency. Nothing here converts to the
-- site's base currency; see the README for why.

WITH source AS (
    SELECT
        *,
        UPPER(NULLIF(TRIM(CAST(currency_code AS STRING)), '')) AS currency,
        CASE
            WHEN UPPER(CAST(currency_code AS STRING)) IN ('JPY', 'KRW', 'XAF', 'XOF') THEN 1
            ELSE 100
        END AS minor_unit_divisor
    FROM {{raw.chargebee.invoice}}
    WHERE COALESCE(CAST(deleted AS BOOL), FALSE) = FALSE
    -- Defensive: one row per invoice even if a sync repeats one.
    QUALIFY ROW_NUMBER() OVER (PARTITION BY id ORDER BY _weld_synced DESC) = 1
)

SELECT
    CAST(id AS STRING)                                          AS invoice_id,
    CAST(customer_id AS STRING)                                 AS customer_id,
    -- NULL on consolidated invoices that cover several subscriptions.
    CAST(subscription_id AS STRING)                             AS subscription_id,
    LOWER(CAST(status AS STRING))                               AS status,
    COALESCE(CAST(recurring AS BOOL), FALSE)                    AS is_recurring,
    COALESCE(CAST(first_invoice AS BOOL), FALSE)                AS is_first_invoice,
    LOWER(CAST(price_type AS STRING))                           AS price_type,

    currency,
    minor_unit_divisor,
    -- Chargebee's rate for converting to the site's base currency. Kept for
    -- reference only; the README explains why the models do not apply it.
    CAST(exchange_rate AS FLOAT64)                              AS exchange_rate,

    CAST(`date` AS TIMESTAMP)                                   AS invoiced_at,
    DATE(CAST(`date` AS TIMESTAMP))                             AS invoice_date,
    DATE(CAST(due_date AS TIMESTAMP))                           AS due_date,
    CAST(paid_at AS TIMESTAMP)                                  AS paid_at,
    CAST(voided_at AS TIMESTAMP)                                AS voided_at,

    -- sub_total is the sum of line amounts minus line discounts, before tax.
    CAST(sub_total AS NUMERIC) / minor_unit_divisor             AS sub_total,
    CAST(tax AS NUMERIC) / minor_unit_divisor                   AS tax,
    CAST(total AS NUMERIC) / minor_unit_divisor                 AS total,
    CAST(amount_paid AS NUMERIC) / minor_unit_divisor           AS amount_paid,
    CAST(amount_adjusted AS NUMERIC) / minor_unit_divisor       AS amount_adjusted,
    CAST(credits_applied AS NUMERIC) / minor_unit_divisor       AS credits_applied,
    CAST(write_off_amount AS NUMERIC) / minor_unit_divisor      AS write_off_amount,
    CAST(amount_due AS NUMERIC) / minor_unit_divisor            AS amount_due,
    CAST(new_sales_amount AS NUMERIC) / minor_unit_divisor      AS new_sales_amount
FROM source
