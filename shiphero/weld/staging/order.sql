-- staging.shiphero.order
-- Thin wrapper over raw `order`. Casts and renames. One row per order.
--
-- MONEY ARRIVES AS STRINGS. ShipHero's API returns prices as strings; they are
-- SAFE_CAST to NUMERIC here so a malformed value becomes NULL instead of failing
-- the model.
--
-- TWO DATES: `order_date` is when the order was placed in the store, `created_at`
-- when it reached ShipHero. Time-to-ship in core is measured from order_date and
-- falls back to created_at.
--
-- `account_id` is the ShipHero account the order belongs to. For a 3PL this is the
-- brand (the 3PL's customer), which is why it is carried through to core.

SELECT
    'account_1'                                              AS shiphero_account,
    CAST(id AS STRING)                                       AS order_id,
    NULLIF(TRIM(CAST(order_number AS STRING)), '')           AS order_number,
    CAST(account_id AS STRING)                               AS account_id,
    NULLIF(TRIM(CAST(shop_name AS STRING)), '')              AS shop_name,
    LOWER(NULLIF(TRIM(CAST(fulfillment_status AS STRING)), '')) AS fulfillment_status,
    UPPER(NULLIF(TRIM(CAST(currency AS STRING)), ''))        AS currency,
    SAFE_CAST(subtotal AS NUMERIC)                           AS subtotal,
    SAFE_CAST(total_discounts AS NUMERIC)                    AS total_discounts,
    SAFE_CAST(total_tax AS NUMERIC)                          AS total_tax,
    SAFE_CAST(total_price AS NUMERIC)                        AS total_price,
    CAST(priority_flag AS BOOL)                              AS is_priority,
    CAST(order_date AS TIMESTAMP)                            AS order_date,
    CAST(required_ship_date AS TIMESTAMP)                    AS required_ship_date,
    CAST(hold_until_date AS TIMESTAMP)                       AS hold_until_date,
    CAST(created_at AS TIMESTAMP)                            AS created_at,
    CAST(updated_at AS TIMESTAMP)                            AS updated_at
FROM {{raw.shiphero.order}}
