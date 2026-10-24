-- stg_chargebee__credit_note_line_item
-- Thin wrapper over raw `credit_note_line_item`. One row per credit note line.
-- Casts, renames, converts minor units to major units using the parent credit
-- note's currency. Amounts stay POSITIVE, as Chargebee stores them.
--
-- A credit note line carries the service period it credits back, which is what
-- lets core reverse the unused part of a plan on a downgrade or a cancellation.

WITH source AS (
    SELECT *
    FROM {{ source('chargebee', 'credit_note_line_item') }}
    QUALIFY ROW_NUMBER() OVER (PARTITION BY id ORDER BY _weld_synced DESC) = 1
)

SELECT
    CAST(l.id AS STRING)                                        AS line_item_id,
    CAST(l.credit_note_id AS STRING)                            AS credit_note_id,
    CAST(l.customer_id AS STRING)                               AS customer_id,
    CAST(l.subscription_id AS STRING)                           AS subscription_id,

    LOWER(CAST(l.entity_type AS STRING))                        AS entity_type,
    CAST(l.entity_id AS STRING)                                 AS entity_id,
    CAST(l.description AS STRING)                               AS description,
    CAST(l.quantity AS INT64)                                   AS quantity,

    CAST(l.date_from AS TIMESTAMP)                              AS service_from,
    CAST(l.date_to AS TIMESTAMP)                                AS service_to,

    c.currency                                                  AS currency,
    c.minor_unit_divisor                                        AS minor_unit_divisor,
    CAST(l.amount AS NUMERIC) / c.minor_unit_divisor            AS amount,
    CAST(COALESCE(l.discount_amount, 0) AS NUMERIC)
        / c.minor_unit_divisor                                  AS discount_amount,
    CAST(COALESCE(l.tax_amount, 0) AS NUMERIC) / c.minor_unit_divisor AS tax_amount,
    CAST(l.amount - COALESCE(l.discount_amount, 0) AS NUMERIC)
        / c.minor_unit_divisor                                  AS net_amount
FROM source l
LEFT JOIN {{ ref('stg_chargebee__credit_note') }} c
       ON c.credit_note_id = CAST(l.credit_note_id AS STRING)
