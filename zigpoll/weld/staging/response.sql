-- staging.zigpoll.response
-- Thin wrapper over raw `response`. One row per participant x slide answered: a
-- participant who answers four questions in one poll produces four rows.
--
-- `response_text` is Zigpoll's display string: for a multi-select answer it is
-- every selected option compiled into one string, so it counts combinations, not
-- options. Count options from response_answer instead.
--
-- Shopify order context (order id, value, currency, UTMs) is captured on the
-- response when the poll runs on a store's thank-you or order status page.
-- Timestamps are UTC.

SELECT
    'account_1'                                  AS zigpoll_account,
    CAST(id AS STRING)                           AS response_id,
    CAST(account_id AS STRING)                   AS account_id,
    CAST(poll_id AS STRING)                      AS poll_id,
    CAST(slide_id AS STRING)                     AS slide_id,
    CAST(participant_id AS STRING)               AS participant_id,
    CAST(response AS STRING)                     AS response_text,
    CAST(value_type AS STRING)                   AS value_type,
    CAST(created_at AS TIMESTAMP)                AS created_at,
    CAST(metadata_completed_poll AS BOOL)        AS completed_poll,
    CAST(order_value AS FLOAT64)                 AS order_value,
    CAST(metadata_shopify_order_id AS STRING)    AS shopify_order_id,
    CAST(metadata_shopify_currency_code AS STRING) AS currency_code,
    CAST(metadata_shopify_country_code AS STRING)  AS country_code,
    CAST(metadata_source AS STRING)              AS source,
    CAST(metadata_url AS STRING)                 AS page_url,
    CAST(metadata_utm_source AS STRING)          AS utm_source,
    CAST(metadata_utm_medium AS STRING)          AS utm_medium,
    CAST(metadata_utm_campaign AS STRING)        AS utm_campaign
FROM {{raw.zigpoll.response}}
QUALIFY ROW_NUMBER() OVER (PARTITION BY id ORDER BY _weld_synced DESC) = 1
