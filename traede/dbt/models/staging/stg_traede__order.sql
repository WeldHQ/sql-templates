-- stg_traede__order
-- Thin wrapper over raw `order`. Casts, renames, turns Traede's flags into booleans.
-- One row per sales order.
--
-- AMOUNTS: all ex VAT unless the name says otherwise, in the order's own currency.
-- Traede's `net_price` on the order header is the order total after discount,
-- excluding shipping and handling. It is renamed to net_amount here so nobody reads
-- it as a unit price (on the order LINE the same field name is per unit).
--
-- `cancelled` and `archived` are booleans in Traede's API but land as strings, so
-- they are parsed here once.

SELECT
    'account_1'                                          AS traede_account,
    CAST(id AS STRING)                                   AS order_id,
    NULLIF(TRIM(CAST(order_number AS STRING)), '')       AS order_number,
    -- Traede order types: b2b, b2c, pos, move, consignment.
    LOWER(NULLIF(TRIM(CAST(type AS STRING)), ''))        AS order_type,
    CAST(customer_id AS STRING)                          AS customer_id,
    -- draft, selection or approved. Only approved orders are confirmed sales.
    LOWER(NULLIF(TRIM(CAST(internal_status AS STRING)), '')) AS internal_status,
    -- Free-text status label configured per Traede account.
    NULLIF(TRIM(CAST(status AS STRING)), '')             AS status,
    COALESCE(LOWER(TRIM(CAST(cancelled AS STRING))) IN ('true', '1', 'yes'), FALSE) AS is_cancelled,
    COALESCE(LOWER(TRIM(CAST(archived AS STRING))) IN ('true', '1', 'yes'), FALSE)  AS is_archived,
    UPPER(NULLIF(TRIM(CAST(currency AS STRING)), ''))    AS currency,

    CAST(price_before_discount AS NUMERIC)               AS gross_amount,
    CAST(discount_amount AS NUMERIC)                     AS discount_amount,
    CAST(net_price AS NUMERIC)                           AS net_amount,
    CAST(shipping AS NUMERIC)                            AS shipping_amount,
    CAST(handling_fee AS NUMERIC)                        AS handling_fee_amount,
    CAST(vat_amount AS NUMERIC)                          AS vat_amount,
    CAST(total_price_after_vat AS NUMERIC)               AS total_incl_vat,

    UPPER(NULLIF(TRIM(CAST(delivery_country AS STRING)), '')) AS delivery_country,

    CAST(approved_at AS TIMESTAMP)                       AS approved_at,
    CAST(created_at AS TIMESTAMP)                        AS created_at,
    CAST(updated_at AS TIMESTAMP)                        AS updated_at
FROM {{ source('traede', 'order') }}
