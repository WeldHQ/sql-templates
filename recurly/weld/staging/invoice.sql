-- staging.recurly.invoice
-- Thin wrapper over raw `invoice`. One row per invoice. Casts, renames, rounds
-- money to cents. No other logic.
--
-- MONEY IS IN MAJOR UNITS. Recurly's API (v3) returns amounts as decimals in the
-- invoice currency: 19.99 means 19.99, not 1999. Nothing is divided here.
--
-- ROUNDED TO 2 DECIMALS because the stream stores amounts as 32-bit floats, so
-- 19.99 can land as 19.9899997711. Rounding restores the value Recurly sent for
-- ordinary amounts; see the README for the limit on very large ones.
--
-- Recurly has three invoice types: `charge` (money owed by the customer),
-- `credit` (money owed to the customer, carried as negative amounts) and `legacy`
-- (invoices from before Recurly split the two). The sign convention is checked by
-- tests/assert_recurly__credit_invoices_are_not_positive.sql.

SELECT
    CAST(id AS STRING)                                          AS invoice_id,
    CAST(account_id AS STRING)                                  AS account_id,
    CAST(number AS STRING)                                      AS invoice_number,
    LOWER(CAST(type AS STRING))                                 AS invoice_type,
    -- purchase, renewal, immediate_change, termination, credit, refund, ...
    LOWER(CAST(origin AS STRING))                               AS origin,
    -- pending, processing, past_due, paid, closed, failed, voided
    LOWER(CAST(state AS STRING))                                AS state,
    LOWER(CAST(collection_method AS STRING))                    AS collection_method,
    UPPER(NULLIF(TRIM(CAST(currency AS STRING)), ''))           AS currency,

    CAST(created_at AS TIMESTAMP)                               AS created_at,
    DATE(CAST(created_at AS TIMESTAMP))                         AS invoice_date,
    DATE(CAST(due_at AS TIMESTAMP))                             AS due_date,
    CAST(closed_at AS TIMESTAMP)                                AS closed_at,

    -- subtotal is charges and credits before discounts and tax.
    ROUND(CAST(subtotal AS NUMERIC), 2)                         AS subtotal,
    ROUND(CAST(COALESCE(discount, 0) AS NUMERIC), 2)            AS discount,
    ROUND(CAST(COALESCE(tax, 0) AS NUMERIC), 2)                 AS tax,
    ROUND(CAST(total AS NUMERIC), 2)                            AS total,
    ROUND(CAST(COALESCE(paid, 0) AS NUMERIC), 2)                AS paid,
    ROUND(CAST(COALESCE(balance, 0) AS NUMERIC), 2)             AS balance,
    ROUND(CAST(COALESCE(refundable_amount, 0) AS NUMERIC), 2)   AS refundable_amount
FROM {{raw.recurly.invoice}}
-- Defensive: one row per invoice even if a sync repeats one.
QUALIFY ROW_NUMBER() OVER (PARTITION BY id ORDER BY _weld_synced DESC) = 1
