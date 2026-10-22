-- staging.zigpoll.response_answer
-- Thin wrapper over raw `response_answer`. One row per selected option on a
-- response: one for a single-choice answer, one per option for a multi-select,
-- one per row (and option) for a matrix, with `answer_rank` set on a ranking.
-- Open-text answers have no rows here; their text is on the response.

SELECT
    'account_1'                                  AS zigpoll_account,
    CAST(response_id AS STRING)                  AS response_id,
    CAST(handle AS STRING)                       AS answer_handle,
    NULLIF(TRIM(CAST(title AS STRING)), '')      AS answer_title,
    CAST(row_handle AS STRING)                   AS row_handle,
    NULLIF(TRIM(CAST(row_title AS STRING)), '')  AS row_title,
    CAST(rank AS INT64)                          AS answer_rank
FROM {{raw.zigpoll.response_answer}}
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY response_id, handle, COALESCE(row_handle, '')
    ORDER BY _weld_synced DESC
) = 1
