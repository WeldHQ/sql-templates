-- stg_mailchimp__list
-- Thin wrapper over raw `list`: one row per Mailchimp audience, with the counts Mailchimp
-- keeps on the audience itself. Casts and renames.
--
-- Grain: list_id.
-- Rates (`avg_sub_rate`, `open_rate` and so on) are Mailchimp's own: open and click rates
-- are percentages (42.1, not 0.421), unlike the fractions on campaign reports.

SELECT
    CAST(id AS STRING)                          AS list_id,
    CAST(web_id AS STRING)                      AS web_id,
    CAST(name AS STRING)                        AS list_name,
    CAST(date_created AS TIMESTAMP)             AS created_at,
    CAST(double_optin AS BOOL)                  AS is_double_optin,
    CAST(stats_member_count AS INT64)           AS subscribed_count,
    CAST(stats_unsubscribe_count AS INT64)      AS unsubscribed_count,
    CAST(stats_cleaned_count AS INT64)          AS cleaned_count,
    CAST(stats_total_contacts AS INT64)         AS total_contacts,
    CAST(stats_campaign_count AS INT64)         AS campaign_count,
    CAST(stats_campaign_last_sent AS TIMESTAMP) AS campaign_last_sent_at,
    CAST(stats_avg_sub_rate AS FLOAT64)         AS avg_monthly_sub_rate,
    CAST(stats_avg_unsub_rate AS FLOAT64)       AS avg_monthly_unsub_rate,
    CAST(stats_open_rate AS FLOAT64)            AS open_rate_pct,
    CAST(stats_click_rate AS FLOAT64)           AS click_rate_pct,
    CAST(stats_last_sub_date AS TIMESTAMP)      AS last_subscribed_at,
    CAST(stats_last_unsub_date AS TIMESTAMP)    AS last_unsubscribed_at
FROM {{ source('mailchimp', 'list') }}
