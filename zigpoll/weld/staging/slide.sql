-- staging.zigpoll.slide
-- Thin wrapper over raw `slide`. One row per question ("slide") in a poll.
--
-- `slide_type` is Zigpoll's question type: question (multiple choice), checkbox,
-- dropdown, range, star-rating, satisfaction, slider, short-answer, long-answer,
-- email-capture, rank, matrix, and non-question slides such as copy and thank-you.
-- Zigpoll has no dedicated NPS type; an NPS question is a range slide with options
-- 0 to 10.

SELECT
    'account_1'                              AS zigpoll_account,
    CAST(id AS STRING)                       AS slide_id,
    CAST(poll_id AS STRING)                  AS poll_id,
    NULLIF(TRIM(CAST(title AS STRING)), '')  AS slide_title,
    CAST(handle AS STRING)                   AS slide_handle,
    CAST(type AS STRING)                     AS slide_type,
    CAST(format AS STRING)                   AS slide_format,
    CAST(optional AS BOOL)                   AS is_optional,
    CAST(created_at AS TIMESTAMP)            AS created_at,
    -- Lifetime totals as of the last sync.
    CAST(view_count AS INT64)                AS view_count,
    CAST(presentation_count AS INT64)        AS presentation_count,
    CAST(engagement_count AS INT64)          AS engagement_count
FROM {{raw.zigpoll.slide}}
QUALIFY ROW_NUMBER() OVER (PARTITION BY id ORDER BY _weld_synced DESC) = 1
