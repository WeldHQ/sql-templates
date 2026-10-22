-- stg_freshdesk__satisfaction_rating
-- One row per survey response, with the answer to the survey's DEFAULT question
-- attached. Casts, renames and one join to the child table.
--
-- The connector syncs the response in `satisfaction_rating` and the answers in
-- `satisfaction_rating_value`, one row per question. Freshdesk's CSAT is the
-- answer to the default question, keyed `default_question`; extra questions on a
-- custom survey are ignored here.
--
-- Freshdesk encodes the answer as a number around 100: 100 is neutral, values
-- above 100 are positive (103 is the happiest) and values below 100, which are
-- negative numbers such as -103, are unhappy. The exact set depends on the
-- survey's point scale, so core classifies by sign rather than by a list.
--
-- The response carries its own agent_id and group_id: the agent and group the
-- ticket had when the survey was answered.

SELECT
    'account_1'                                AS freshdesk_account,
    CAST(r.id AS STRING)                       AS rating_id,
    CAST(r.ticket_id AS STRING)                AS ticket_id,
    CAST(r.agent_id AS STRING)                 AS agent_id,
    CAST(r.group_id AS STRING)                 AS group_id,
    CAST(r.survey_id AS STRING)                AS survey_id,
    CAST(r.created_at AS TIMESTAMP)            AS created_at,
    CAST(v.value AS INT64)                     AS rating_value
FROM {{ source('freshdesk', 'satisfaction_rating') }} r
LEFT JOIN {{ source('freshdesk', 'satisfaction_rating_value') }} v
       ON CAST(v.satisfaction_rating_id AS STRING) = CAST(r.id AS STRING)
      AND v.survey_question_id = 'default_question'
WHERE r.id IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY r.id ORDER BY r.updated_at DESC) = 1
