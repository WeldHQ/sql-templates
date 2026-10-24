-- stg_zigpoll__slide_answer
-- Thin wrapper over raw `slide_answer`. One row per answer option defined on a
-- slide, with Zigpoll's lifetime vote count for it. Core uses the option titles to
-- recognise a 0 to 10 scale.

SELECT
    'account_1'                              AS zigpoll_account,
    CAST(slide_id AS STRING)                 AS slide_id,
    CAST(handle AS STRING)                   AS answer_handle,
    NULLIF(TRIM(CAST(title AS STRING)), '')  AS answer_title,
    CAST(votes AS INT64)                     AS votes
FROM {{ source('zigpoll', 'slide_answer') }}
QUALIFY ROW_NUMBER() OVER (PARTITION BY slide_id, handle ORDER BY _weld_synced DESC) = 1
