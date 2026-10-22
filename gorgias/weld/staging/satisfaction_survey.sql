-- staging.gorgias.satisfaction_survey
-- Thin wrapper over raw `satisfaction_survey`. One row per survey, at most one per
-- ticket. score is 1 to 5 and is NULL until the customer answers.

SELECT
    'account_1'                                  AS gorgias_account,
    CAST(id AS STRING)                           AS survey_id,
    CAST(ticket_id AS STRING)                    AS ticket_id,
    CAST(customer_id AS STRING)                  AS customer_id,
    CAST(score AS INT64)                         AS score,
    CAST(created_datetime AS TIMESTAMP)          AS created_at,
    CAST(sent_datetime AS TIMESTAMP)             AS sent_at,
    CAST(scored_datetime AS TIMESTAMP)           AS scored_at
FROM {{raw.gorgias.satisfaction_survey}}
WHERE id IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY id ORDER BY scored_datetime DESC NULLS LAST) = 1
