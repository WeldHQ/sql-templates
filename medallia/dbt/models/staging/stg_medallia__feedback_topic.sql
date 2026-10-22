-- stg_medallia__feedback_topic
-- Thin wrapper over raw `feedback_topic`. One row per comment x text analytics
-- topic it was tagged with (Medallia's rule-based topics). A comment can carry
-- several topics, and a record several comments.
--
-- Up to 100 topics are read per comment. Like answers, a topic removed from a
-- record by a later re-tag stays until the table is fully re-synced.

SELECT
    'account_1'                                AS medallia_account,
    CAST(feedback_id AS STRING)                AS feedback_id,
    CAST(question_id AS STRING)                AS question_id,
    CAST(topic_id AS STRING)                   AS topic_id,
    NULLIF(TRIM(CAST(topic_name AS STRING)), '') AS topic_name
FROM {{ source('medallia', 'feedback_topic') }}
QUALIFY ROW_NUMBER() OVER (PARTITION BY feedback_id, question_id, topic_id ORDER BY _weld_synced DESC) = 1
