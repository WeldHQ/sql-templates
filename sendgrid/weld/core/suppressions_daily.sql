-- core.sendgrid.suppressions_daily
-- New suppressions per day, by type: the list-hygiene view behind SendGrid's
-- Suppressions pages (Bounces, Blocks, Invalid Emails, Spam Reports, Global Unsubscribes).
--
-- Grain: one row per day (UTC, from the suppression's `created` time) x suppression type.
-- Depends on: staging.sendgrid.bounce, .block, .invalid_email, .spam_report,
--             .global_unsubscribe
--
-- A rising spam-report or block count is an early warning of a sending-reputation problem,
-- well before delivery rates move. Unsubscribes from individual unsubscribe groups are not
-- in this model: group membership (`group_suppression`) is synced without a date.
--
-- `addresses` counts distinct addresses within the row. The same address can appear on
-- several lists (a hard bounce that was also reported as spam), so summing `addresses`
-- across types overstates the number of people.

WITH suppressions AS (
    SELECT email, created_at, suppression_type FROM {{staging.sendgrid.bounce}}
    UNION ALL
    SELECT email, created_at, suppression_type FROM {{staging.sendgrid.block}}
    UNION ALL
    SELECT email, created_at, suppression_type FROM {{staging.sendgrid.invalid_email}}
    UNION ALL
    SELECT email, created_at, suppression_type FROM {{staging.sendgrid.spam_report}}
    UNION ALL
    SELECT email, created_at, suppression_type FROM {{staging.sendgrid.global_unsubscribe}}
)

SELECT
    DATE(created_at)                AS date,
    suppression_type,
    COUNT(*)                        AS suppressions,
    COUNT(DISTINCT email)           AS addresses
FROM suppressions
WHERE created_at IS NOT NULL
GROUP BY 1, 2
