-- staging.app_store_connect.customer_reviews
-- Thin wrapper over raw `customer_reviews`: App Store ratings that came with a
-- written review, and your replies. Casts, renames, keeps the latest row per
-- review. Reviewer nickname and review text are left out; add them back if you
-- read reviews in the warehouse.
--
-- Grain: one row per review.
--
-- TERRITORY IS A THREE-LETTER CODE here ('USA', 'DEU'). Apple's analytics reports
-- and the Sales report use two-letter codes ('US', 'DE'), so the column is named
-- territory_alpha3 to stop it being joined to those as if it matched.
--
-- Star-only ratings without text are not returned by Apple's API, so the average
-- rating here is the average of written reviews, not the rating shown on the App
-- Store.

SELECT * EXCEPT (row_rank)
FROM (
    SELECT
        CAST(id AS STRING)                          AS review_id,
        CAST(app_id AS STRING)                      AS app_apple_id,
        CAST(rating AS INT64)                       AS rating,
        CAST(title AS STRING)                       AS review_title,
        CAST(created_date AS TIMESTAMP)             AS created_at,
        DATE(CAST(created_date AS TIMESTAMP))       AS created_date,
        UPPER(CAST(territory AS STRING))            AS territory_alpha3,
        CAST(response_id AS STRING)                 AS response_id,
        CAST(response_last_modified_date AS TIMESTAMP) AS response_modified_at,
        CAST(response_state AS STRING)              AS response_state,
        ROW_NUMBER() OVER (PARTITION BY id ORDER BY _weld_synced DESC) AS row_rank
    FROM {{raw.app_store_connect.customer_reviews}}
)
WHERE row_rank = 1
