-- stg_shopify__order_agreement_sale
-- Line-level money per event, in both shop money (the store's base currency) and
-- presentment money (what the customer actually paid in).
--
-- amount_ex_tax is derived here because total_amount is tax-inclusive while every
-- sales component except taxes is not - computing it once avoids repeating the
-- subtraction in every consumer.
--
-- Single store. To add another, UNION ALL a second block below pointing at that
-- store's connector with a different shopify_store label. Keep it in staging so
-- the core models never have to know how many stores there are.

{{ config(materialized='table') }}

SELECT
    'store_1'                     AS shopify_store,
    CAST(order_agreement_id AS STRING) AS order_agreement_id,
    CAST(order_id AS INT64)            AS order_id,
    UPPER(CAST(line_type AS STRING))   AS line_type,
    UPPER(CAST(action_type AS STRING)) AS action_type,
    COALESCE(CAST(quantity AS INT64), 0) AS quantity,

    COALESCE(CAST(total_amount_shop_money_amount AS NUMERIC), 0)     AS total_amount,
    COALESCE(CAST(total_tax_amount_shop_money_amount AS NUMERIC), 0) AS total_tax,
    COALESCE(CAST(total_discount_amount_before_taxes_shop_money_amount AS NUMERIC), 0)
                                                                     AS discount_before_tax,
    COALESCE(CAST(total_amount_shop_money_amount AS NUMERIC), 0)
      - COALESCE(CAST(total_tax_amount_shop_money_amount AS NUMERIC), 0) AS amount_ex_tax,

    COALESCE(CAST(total_amount_presentment_money_amount AS NUMERIC), 0)     AS presentment_total_amount,
    COALESCE(CAST(total_tax_amount_presentment_money_amount AS NUMERIC), 0) AS presentment_total_tax,
    COALESCE(CAST(total_discount_amount_before_taxes_presentment_money_amount AS NUMERIC), 0)
                                                                            AS presentment_discount_before_tax,
    COALESCE(CAST(total_amount_presentment_money_amount AS NUMERIC), 0)
      - COALESCE(CAST(total_tax_amount_presentment_money_amount AS NUMERIC), 0) AS presentment_amount_ex_tax,
    UPPER(CAST(total_amount_presentment_money_currency_code AS STRING))      AS presentment_currency
FROM {{ source('shopify', 'order_agreement_sale') }}
