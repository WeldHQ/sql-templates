-- core.mailchimp.audience_growth_daily
-- Mailchimp's audience growth and activity, per audience per day: new subscribers,
-- unsubscribes and other changes, plus the sending activity on that day.
--
-- Grain: one row per day x audience (list).
-- Depends on: staging.mailchimp.list_activity, .list
--
-- `net_change` follows Mailchimp's audience growth chart: subscribes and other adds
-- (imports, API) in, unsubscribes and other removes (cleaned, deleted, archived) out.
-- Summing it over a window gives the change in subscribed contacts for that window.
--
-- `unique_opens` and `recipient_clicks` are per day as Mailchimp reports them, so they
-- cannot be summed into unique people over a longer window. The open and click rates are
-- per row; re-derive them from summed counts when you aggregate.

SELECT
    a.day,
    a.list_id,
    l.list_name,

    a.subscribes,
    a.other_adds,
    a.unsubscribes,
    a.other_removes,
    COALESCE(a.subscribes, 0) + COALESCE(a.other_adds, 0)
        - COALESCE(a.unsubscribes, 0) - COALESCE(a.other_removes, 0)  AS net_change,

    a.emails_sent,
    a.hard_bounces,
    a.soft_bounces,
    a.unique_opens,
    a.recipient_clicks,
    SAFE_DIVIDE(a.unique_opens, a.emails_sent)                        AS unique_open_rate,
    SAFE_DIVIDE(a.recipient_clicks, a.emails_sent)                    AS click_rate
FROM {{staging.mailchimp.list_activity}} a
LEFT JOIN {{staging.mailchimp.list}} l ON l.list_id = a.list_id
