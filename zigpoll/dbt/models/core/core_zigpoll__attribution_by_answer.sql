-- core_zigpoll__attribution_by_answer
-- Orders and revenue per answer option, for post-purchase questions such as "How
-- did you hear about us?".
-- Grain: month x zigpoll_account x poll x slide x answer x currency. Months are UTC
-- calendar months of the response. Only responses carrying a Shopify order id,
-- synthetic polls excluded.
-- Depends on: core.zigpoll.answer_detail
--
-- Revenue is `order_value` as Zigpoll captured it on the response, in the order's
-- own currency. Currency is part of the grain because summing EUR and USD orders
-- into one number is meaningless; convert downstream if you need one figure.
--
-- MULTI-SELECT: an order whose buyer ticked "Instagram" and "A friend" counts in
-- full under both. Each row is right on its own, but the rows of one slide add up
-- to more than total revenue. For a single-choice slide they add up exactly.
--
-- Each order is counted once per answer even if the buyer somehow answered twice:
-- orders and revenue are taken per distinct order id.

WITH order_answers AS (
    SELECT DISTINCT
        zigpoll_account,
        poll_id,
        poll_title,
        slide_id,
        slide_title,
        DATE_TRUNC(response_date, MONTH) AS month,
        answer_value,
        currency_code,
        shopify_order_id,
        order_value
    FROM {{ ref('core_zigpoll__answer_detail') }}
    WHERE shopify_order_id IS NOT NULL
      AND answer_value IS NOT NULL
      AND NOT COALESCE(is_synthetic, FALSE)
      -- Open text has no options to group on; matrix and rank answers need their
      -- row or rank to mean anything, which this grain does not carry.
      AND COALESCE(slide_type, '') NOT IN ('short-answer', 'long-answer', 'email-capture', 'phone-capture', 'matrix', 'rank')
)

SELECT
    month,
    zigpoll_account,
    poll_id,
    poll_title,
    slide_id,
    slide_title,
    answer_value,
    currency_code,
    COUNT(DISTINCT shopify_order_id) AS orders,
    SUM(order_value)                 AS revenue,
    SAFE_DIVIDE(SUM(order_value), COUNT(DISTINCT shopify_order_id)) AS avg_order_value
FROM order_answers
GROUP BY 1, 2, 3, 4, 5, 6, 7, 8
