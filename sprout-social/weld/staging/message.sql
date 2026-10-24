-- staging.sprout_social.message
-- Thin wrapper over raw `message`: every message published by or received by a
-- connected profile (posts, comments, mentions, direct messages, reviews and the
-- replies to them). Casts, renames, keeps the latest row per message.
--
-- Grain: one row per message (guid).
--
-- Timestamps are UTC. is_sent compares the author with the receiving profile: the
-- message counts as sent when the connected profile wrote it. internal_sent_by_id
-- is only filled when a Sprout user sent it from Sprout.

SELECT * EXCEPT (row_rank)
FROM (
    SELECT
        CAST(guid AS STRING)                     AS message_id,
        CAST(customer_profile_id AS STRING)      AS customer_profile_id,
        CAST(profile_guid AS STRING)             AS profile_guid,
        CAST(created_time AS TIMESTAMP)          AS created_at,
        UPPER(CAST(network AS STRING))           AS network,
        CAST(post_category AS STRING)            AS post_category,
        CAST(post_type AS STRING)                AS post_type,
        CAST(content_category AS STRING)         AS content_category,
        CAST(from_guid AS STRING)                AS author_guid,
        CAST(from_name AS STRING)                AS author_name,
        CAST(from_screen_name AS STRING)         AS author_screen_name,
        COALESCE(CAST(from_guid AS STRING) = CAST(profile_guid AS STRING), FALSE) AS is_sent,
        CAST(internal_sent_by_id AS STRING)      AS sent_by_user_id,
        TRIM(CONCAT(COALESCE(CAST(internal_sent_by_first_name AS STRING), ''), ' ',
                    COALESCE(CAST(internal_sent_by_last_name AS STRING), ''))) AS sent_by_user_name,
        CAST(case_id AS STRING)                  AS case_id,
        CAST(internal_tags AS STRING)            AS internal_tags_json,
        CAST(perma_link AS STRING)               AS permalink,
        CAST(inbox_permalink AS STRING)          AS inbox_permalink,
        ROW_NUMBER() OVER (PARTITION BY guid ORDER BY _weld_synced DESC) AS row_rank
    FROM {{raw.sprout_social.message}}
)
WHERE row_rank = 1
