-- stg_dandomain_webshop__order
-- Thin wrapper over raw `order`: one row per order or credit note. Casts, renames,
-- blanks to NULL, and keeps the latest copy of each order.
--
-- DATES. DanDomain's API returns datetimes without a time zone, in the shop's local
-- time, and they are stored as given. So DATE(order_created_at) is already the
-- shop's own calendar day: do not convert it again. Despite its name,
-- date_delivered is the order's CREATION datetime in DanDomain's API; date_sent is
-- when it was marked as sent, and date_due is the payment due date.
--
-- WHY THE DE-DUPLICATION. Orders are re-fetched whenever they change. The latest
-- copy wins, so a status change or edit replaces the old row rather than adding a
-- second one.
--
-- Single shop. To add another, UNION ALL a second block below pointing at that
-- shop's connector with a different dandomain_shop label. Order IDs are only unique
-- within a shop.

SELECT
    'shop_1'                                                    AS dandomain_shop,
    CAST(id AS INT64)                                           AS order_id,
    CAST(date_delivered AS TIMESTAMP)                           AS order_created_at,
    CAST(date_sent AS TIMESTAMP)                                AS order_sent_at,
    CAST(date_updated AS TIMESTAMP)                             AS order_updated_at,

    -- DanDomain's fixed status IDs: 0 Not received, 1 Order received,
    -- 2 Processing, 3 Order sent, 4 Reopened, 5 Cancelled, 6 Ready for pickup,
    -- 7 Partially sent, 8 Picked up, 99 Draft, 100 Credit note.
    SAFE_CAST(status AS INT64)                                  AS status_id,

    CAST(site AS INT64)                                         AS site_id,
    NULLIF(TRIM(CAST(origin AS STRING)), '')                    AS origin,
    NULLIF(TRIM(CAST(language_iso AS STRING)), '')              AS language_iso,
    CAST(invoice_number AS INT64)                               AS invoice_number,
    NULLIF(TRIM(CAST(reference_number AS STRING)), '')          AS reference_number,

    CAST(user_id AS INT64)                                      AS user_id,
    COALESCE(CAST(customer_b2b AS BOOL), FALSE)                 AS is_b2b,
    UPPER(NULLIF(TRIM(CAST(customer_country_code AS STRING)), ''))          AS customer_country_code,
    UPPER(NULLIF(TRIM(CAST(customer_shipping_country_code AS STRING)), '')) AS shipping_country_code,

    UPPER(NULLIF(TRIM(CAST(currency_iso AS STRING)), ''))       AS currency_iso,
    -- The currency's value against the shop's base currency at order time.
    CAST(currency_currency AS NUMERIC)                          AS currency_rate,

    -- Order VAT is a PERCENTAGE (25 for Danish VAT), not an amount.
    CAST(vat AS NUMERIC)                                        AS vat_percentage,

    NULLIF(TRIM(CAST(delivery_title AS STRING)), '')            AS delivery_title,
    CAST(delivery_price AS NUMERIC)                             AS delivery_price,
    COALESCE(CAST(delivery_vat AS BOOL), FALSE)                 AS delivery_has_vat,
    NULLIF(TRIM(CAST(payment_title AS STRING)), '')             AS payment_title,
    CAST(payment_price AS NUMERIC)                              AS payment_fee,
    COALESCE(CAST(payment_vat AS BOOL), FALSE)                  AS payment_has_vat,

    -- Deprecated by DanDomain: "the total price of the order without VAT, shipping
    -- and transaction price", and documented as possibly wrong. Kept only to compare
    -- against the line-based net in core; never summed.
    CAST(total AS NUMERIC)                                      AS reported_total_deprecated
FROM {{ source('dandomain_webshop', 'order') }}
WHERE id IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY id ORDER BY date_updated DESC, _weld_synced DESC) = 1
