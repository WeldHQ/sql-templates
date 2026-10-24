-- stg_traede__invoice
-- Thin wrapper over raw `invoice`. One row per invoice, drafts included.
--
-- STATUS: Traede invoices are `draft` or `booked`. Only booked invoices have an
-- invoice number and count as revenue; is_booked is derived here so core does not
-- repeat the string match.
--
-- DATE: `invoice_date` lands as a string. It is parsed from its first ten
-- characters (YYYY-MM-DD) and falls back to the creation date when it is empty or
-- does not parse, so no booked invoice drops out of a time series for want of a
-- date.
--
-- AMOUNTS: ex VAT unless named otherwise, in the invoice's own currency.
-- `net_price` on the header is the total after discount, excluding shipping and
-- handling fee, and is renamed net_amount.
--
-- NOT SYNCED: credit notes are a separate Traede resource and the connector does
-- not sync them, so nothing here nets credits off invoiced revenue.

SELECT
    'account_1'                                          AS traede_account,
    CAST(id AS STRING)                                   AS invoice_id,
    NULLIF(TRIM(CAST(invoice_number AS STRING)), '')     AS invoice_number,
    CAST(customer_id AS STRING)                          AS customer_id,
    -- NULL for a manual invoice that was not raised from an order.
    CAST(order_id AS STRING)                             AS order_id,
    LOWER(NULLIF(TRIM(CAST(order_type AS STRING)), ''))  AS order_type,
    COALESCE(
        SAFE_CAST(SUBSTR(TRIM(CAST(invoice_date AS STRING)), 1, 10) AS DATE),
        DATE(CAST(created_at AS TIMESTAMP))
    )                                                    AS invoice_date,
    LOWER(NULLIF(TRIM(CAST(status AS STRING)), ''))      AS status,
    COALESCE(LOWER(TRIM(CAST(status AS STRING))) = 'booked', FALSE) AS is_booked,
    UPPER(NULLIF(TRIM(CAST(currency AS STRING)), ''))    AS currency,

    CAST(total_quantity AS INT64)                        AS total_quantity,
    CAST(price_before_discount AS NUMERIC)               AS gross_amount,
    CAST(discount_amount AS NUMERIC)                     AS discount_amount,
    CAST(net_price AS NUMERIC)                           AS net_amount,
    CAST(shipping AS NUMERIC)                            AS shipping_amount,
    CAST(handling_fee AS NUMERIC)                        AS handling_fee_amount,
    CAST(vat_amount AS NUMERIC)                          AS vat_amount,
    CAST(total_price_after_vat AS NUMERIC)               AS total_incl_vat,

    CAST(created_at AS TIMESTAMP)                        AS created_at,
    CAST(updated_at AS TIMESTAMP)                        AS updated_at
FROM {{ source('traede', 'invoice') }}
