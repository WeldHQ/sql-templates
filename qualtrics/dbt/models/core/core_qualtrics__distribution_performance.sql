-- core_qualtrics__distribution_performance
-- Email distribution funnel: sent, bounced, opened, started, finished, and the rates
-- between them, per distribution.
-- Grain: qualtrics_account x distribution. Dated by `sent_at`.
-- Depends on: staging.qualtrics.distribution, .survey
--
-- This recreates the per-distribution stats on Qualtrics' Distributions tab. The
-- counts are Qualtrics' own running totals as of the last time the connector read
-- the distribution (see staging/distribution.sql), so a distribution sent months
-- ago may show slightly lower started and finished figures than the UI if
-- respondents kept trickling in after it left the connector's look-back window.
--
-- RATES ARE PER DISTRIBUTION. To roll up to survey or month, sum the counts and
-- divide, never average the rates. Reminders and thank-yous are separate rows,
-- linked to their invite by `parent_distribution_id`; filter on
-- `request_type = 'Invite'` before summing `sent` if you want people invited
-- rather than emails sent.

SELECT
    d.qualtrics_account,
    d.distribution_id,
    d.parent_distribution_id,
    d.survey_id,
    s.survey_name,
    d.request_type,
    d.request_status,
    d.link_type,
    d.mailing_list_id,
    d.from_name,
    d.sent_at,
    DATE(d.sent_at) AS sent_date,

    d.sent,
    d.failed,
    d.bounced,
    d.blocked,
    d.skipped,
    d.complaints,
    d.opened,
    d.started,
    d.finished,

    -- Delivered is sent minus bounced. Qualtrics counts failed and skipped emails
    -- separately from sent, so they are not subtracted again.
    d.sent - COALESCE(d.bounced, 0)                         AS delivered,
    SAFE_DIVIDE(d.bounced, d.sent)                          AS bounce_rate,
    SAFE_DIVIDE(d.opened, d.sent - COALESCE(d.bounced, 0))  AS open_rate,
    SAFE_DIVIDE(d.started, d.sent - COALESCE(d.bounced, 0)) AS start_rate,
    -- Finished over delivered: the share of reachable recipients who completed it.
    SAFE_DIVIDE(d.finished, d.sent - COALESCE(d.bounced, 0)) AS response_rate,
    -- Of those who opened the survey, how many finished it.
    SAFE_DIVIDE(d.finished, d.started)                      AS completion_rate
FROM {{ ref('stg_qualtrics__distribution') }} d
LEFT JOIN {{ ref('stg_qualtrics__survey') }} s
       ON s.qualtrics_account = d.qualtrics_account
      AND s.survey_id         = d.survey_id
