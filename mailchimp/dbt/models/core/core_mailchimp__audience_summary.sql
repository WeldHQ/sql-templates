-- core_mailchimp__audience_summary
-- One row per audience: Mailchimp's own contact counts next to the same counts rebuilt
-- from the synced members, plus member quality signals.
--
-- Grain: one row per audience (list), as of the last sync.
-- Depends on: staging.mailchimp.list, .member
--
-- The `*_count` columns are Mailchimp's numbers from the audience itself and match the
-- Audience dashboard. The `members_*` columns count the synced member rows by status. The
-- two should agree; a gap usually means the member stream is behind or was filtered.
-- Archived contacts are counted only in `members_archived`; Mailchimp leaves them out of
-- its audience totals.

WITH members AS (
    SELECT
        list_id,
        COUNTIF(status = 'subscribed')                      AS members_subscribed,
        COUNTIF(status = 'unsubscribed')                    AS members_unsubscribed,
        COUNTIF(status = 'cleaned')                         AS members_cleaned,
        COUNTIF(status = 'pending')                         AS members_pending,
        COUNTIF(status = 'transactional')                   AS members_transactional,
        COUNTIF(status = 'archived')                        AS members_archived,
        AVG(IF(status = 'subscribed', member_rating, NULL)) AS avg_member_rating_subscribed,
        COUNTIF(status = 'subscribed'
                AND signed_up_at >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY))
                                                            AS subscribed_last_30_days
    FROM {{ ref('stg_mailchimp__member') }}
    GROUP BY 1
)

SELECT
    l.list_id,
    l.list_name,
    l.created_at,
    l.is_double_optin,

    l.subscribed_count,
    l.unsubscribed_count,
    l.cleaned_count,
    l.total_contacts,
    l.avg_monthly_sub_rate,
    l.avg_monthly_unsub_rate,
    l.open_rate_pct,
    l.click_rate_pct,
    l.campaign_count,
    l.campaign_last_sent_at,

    m.members_subscribed,
    m.members_unsubscribed,
    m.members_cleaned,
    m.members_pending,
    m.members_transactional,
    m.members_archived,
    m.subscribed_last_30_days,
    m.avg_member_rating_subscribed
FROM {{ ref('stg_mailchimp__list') }} l
LEFT JOIN members m ON m.list_id = l.list_id
