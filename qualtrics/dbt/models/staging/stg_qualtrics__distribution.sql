-- stg_qualtrics__distribution
-- Thin wrapper over raw `distribution`. One row per email distribution: an invite,
-- a reminder or a thank-you send.
--
-- The stats_* columns are Qualtrics' own running totals for the distribution, as
-- of the last sync, not events. The connector re-reads the last week of
-- distributions once a day so recent sends keep updating; an older distribution
-- keeps the totals it had when it last fell inside that window.
--
-- SMS distributions are a separate stream (`sms_distribution`) with the same
-- columns; they are not included here.

SELECT
    'account_1'                                 AS qualtrics_account,
    CAST(id AS STRING)                          AS distribution_id,
    CAST(parent_distribution_id AS STRING)      AS parent_distribution_id,
    CAST(survey_link_survey_id AS STRING)       AS survey_id,
    -- Invite, Reminder, ThankYou, GeneratedInvite, ...
    CAST(request_type AS STRING)                AS request_type,
    CAST(request_status AS STRING)              AS request_status,
    CAST(survey_link_link_type AS STRING)       AS link_type,
    CAST(recipients_mailing_list_id2 AS STRING) AS mailing_list_id,
    CAST(headers_from_name AS STRING)           AS from_name,
    CAST(send_date AS TIMESTAMP)                AS sent_at,
    CAST(created_date AS TIMESTAMP)             AS created_at,
    CAST(stats_sent AS INT64)                   AS sent,
    CAST(stats_failed AS INT64)                 AS failed,
    CAST(stats_bounced AS INT64)                AS bounced,
    CAST(stats_blocked AS INT64)                AS blocked,
    CAST(stats_skipped AS INT64)                AS skipped,
    CAST(stats_complaints AS INT64)             AS complaints,
    CAST(stats_opened AS INT64)                 AS opened,
    CAST(stats_started AS INT64)                AS started,
    CAST(stats_finished AS INT64)               AS finished
FROM {{ source('qualtrics', 'distribution') }}
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY id, parent_distribution_id, survey_link_survey_id
    ORDER BY _weld_synced DESC
) = 1
