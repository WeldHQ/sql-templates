-- core_zigpoll__answer_detail
-- Every answer, in long format, with selected options unnested.
-- Grain: zigpoll_account x response x selected option (x matrix row). A response
-- with no option rows (open text, email capture, slider) is one row with NULL
-- option columns and its text in `response_text`.
-- Depends on: staging.zigpoll.response, .response_answer, .slide, .poll
--
-- For an answer distribution, count rows per `answer_value` for one slide. On a
-- multi-select slide the counts add up to more than the number of respondents;
-- divide by COUNT(DISTINCT participant_id) for the share of respondents who picked
-- each option. Do not group on `response_text` for that: it is the compiled
-- display string, so "A, B" and "A" are different values.

SELECT
    r.zigpoll_account,
    r.poll_id,
    p.poll_title,
    p.is_synthetic,
    r.slide_id,
    s.slide_title,
    s.slide_type,
    r.response_id,
    r.participant_id,
    r.created_at,
    DATE(r.created_at) AS response_date,
    r.completed_poll,

    a.answer_handle,
    a.answer_title,
    a.row_handle,
    a.row_title,
    a.answer_rank,
    r.response_text,
    -- One display value per row: the option when there is one, the text otherwise.
    COALESCE(a.answer_title, r.response_text) AS answer_value,

    -- Order context. Repeated on every option row of a multi-select answer, so sum
    -- it per distinct shopify_order_id, never per row (see attribution_by_answer).
    r.shopify_order_id,
    r.order_value,
    r.currency_code,
    r.utm_source,
    r.utm_medium,
    r.utm_campaign
FROM {{ ref('stg_zigpoll__response') }} r
-- LEFT: open-text answers have no option rows. The join is on the response id
-- only, so it fans a response out into its selected options and nothing else.
LEFT JOIN {{ ref('stg_zigpoll__response_answer') }} a
       ON a.zigpoll_account = r.zigpoll_account
      AND a.response_id     = r.response_id
LEFT JOIN {{ ref('stg_zigpoll__slide') }} s
       ON s.zigpoll_account = r.zigpoll_account
      AND s.slide_id        = r.slide_id
LEFT JOIN {{ ref('stg_zigpoll__poll') }} p
       ON p.zigpoll_account = r.zigpoll_account
      AND p.poll_id         = r.poll_id
