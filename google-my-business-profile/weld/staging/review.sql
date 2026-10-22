-- staging.google_my_business_profile.review
-- Thin wrapper over raw `review`. Casts, renames, turns the star rating enum into
-- a number, keeps the latest row per review. No other logic.
--
-- Grain: one row per review. A review the customer deletes disappears from the
-- API and, after the next full sync, from this table.

SELECT * EXCEPT (row_rank)
FROM (
    SELECT
        CAST(review_id AS STRING)              AS review_id,
        CAST(account_id AS STRING)             AS account_id,
        CAST(location_id AS STRING)            AS location_id,
        CASE UPPER(CAST(star_rating AS STRING))
            WHEN 'ONE'   THEN 1
            WHEN 'TWO'   THEN 2
            WHEN 'THREE' THEN 3
            WHEN 'FOUR'  THEN 4
            WHEN 'FIVE'  THEN 5
        END                                    AS star_rating,
        CAST(create_time AS TIMESTAMP)         AS created_at,
        CAST(update_time AS TIMESTAMP)         AS updated_at,
        NULLIF(CAST(comment AS STRING), '')    AS comment,
        NULLIF(CAST(review_reply_comment AS STRING), '') AS reply_comment,
        -- The reply's last edit time, not necessarily when it was first posted.
        SAFE_CAST(review_reply_update_time AS TIMESTAMP) AS reply_updated_at,
        ROW_NUMBER() OVER (PARTITION BY review_id ORDER BY _weld_synced DESC) AS row_rank
    FROM {{raw.google_my_business_profile.review}}
    WHERE review_id IS NOT NULL
)
WHERE row_rank = 1
