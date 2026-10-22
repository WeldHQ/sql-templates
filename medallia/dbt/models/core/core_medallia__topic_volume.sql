-- core_medallia__topic_volume
-- How often each text analytics topic comes up in comments, per unit per month.
-- Grain: month x medallia_account x unit x topic. Months are UTC calendar months
-- of the record's `responded_at`.
-- Depends on: staging.medallia.feedback_topic, .feedback, .unit
--
-- `feedback_records` counts records with at least one comment tagged with the
-- topic, so a record that mentions "wait time" in two comments counts once.
-- `share_of_commenting_records` divides by records in the same unit and month
-- that carry any tagged comment, the usual "% of comments mentioning" figure.
-- Both are distinct counts: sum neither across months or units; recount instead.

WITH tagged AS (
    SELECT DISTINCT
        t.medallia_account,
        DATE_TRUNC(DATE(f.responded_at), MONTH) AS month,
        f.unit_identifier,
        t.topic_id,
        t.topic_name,
        t.feedback_id
    FROM {{ ref('stg_medallia__feedback_topic') }} t
    INNER JOIN {{ ref('stg_medallia__feedback') }} f
            ON f.medallia_account = t.medallia_account
           AND f.feedback_id      = t.feedback_id
    WHERE f.responded_at IS NOT NULL
),

commenting AS (
    SELECT
        medallia_account,
        month,
        unit_identifier,
        COUNT(DISTINCT feedback_id) AS commenting_records
    FROM tagged
    GROUP BY 1, 2, 3
),

topics AS (
    SELECT
        medallia_account,
        month,
        unit_identifier,
        topic_id,
        -- A topic can be renamed; take one name per id so the rename does not
        -- split the topic into two rows.
        MAX(topic_name)             AS topic_name,
        COUNT(DISTINCT feedback_id) AS feedback_records
    FROM tagged
    GROUP BY 1, 2, 3, 4
)

SELECT
    t.month,
    t.medallia_account,
    t.unit_identifier,
    u.unit_name,
    t.topic_id,
    t.topic_name,
    t.feedback_records,
    c.commenting_records,
    SAFE_DIVIDE(t.feedback_records, c.commenting_records) AS share_of_commenting_records
FROM topics t
INNER JOIN commenting c
        ON c.medallia_account = t.medallia_account
       AND c.month            = t.month
       AND COALESCE(c.unit_identifier, '') = COALESCE(t.unit_identifier, '')
LEFT JOIN {{ ref('stg_medallia__unit') }} u
       ON u.medallia_account = t.medallia_account
      AND u.unit_identifier  = t.unit_identifier
