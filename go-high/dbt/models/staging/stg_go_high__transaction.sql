-- stg_go_high__transaction
-- Thin wrapper over raw `transaction`: one row per payment taken through HighLevel
-- Payments (funnels, invoices, subscriptions, order forms). Casts and renames.
--
-- Grain: transaction_id.
-- Transactions are synced per location and HighLevel records the location as
-- `alt_id` when `alt_type` is "location"; that is surfaced as `location_id`.
-- `amount` and `amount_refunded` are in the transaction's currency as HighLevel returns
-- them. Check one transaction against Payments > Transactions in HighLevel to confirm the
-- unit before relying on totals. Test-mode payments are kept and flagged by `is_live`.

SELECT
    CAST(id AS STRING)                          AS transaction_id,
    IF(LOWER(CAST(alt_type AS STRING)) = 'location',
       CAST(alt_id AS STRING), NULL)            AS location_id,
    CAST(contact_id AS STRING)                  AS contact_id,
    CAST(subscription_id AS STRING)             AS subscription_id,
    UPPER(CAST(currency AS STRING))             AS currency,
    CAST(amount AS NUMERIC)                     AS amount,
    COALESCE(CAST(amount_refunded AS NUMERIC), 0) AS amount_refunded,
    LOWER(CAST(status AS STRING))               AS status,
    CAST(live_mode AS BOOL)                     AS is_live,
    LOWER(CAST(entity_type AS STRING))          AS entity_type,
    LOWER(CAST(entity_source_type AS STRING))   AS source_type,
    CAST(entity_source_name AS STRING)          AS source_name,
    LOWER(CAST(payment_provider_type AS STRING)) AS payment_provider,
    CAST(created_at AS TIMESTAMP)               AS created_at
FROM {{ source('go_high', 'transaction') }}
