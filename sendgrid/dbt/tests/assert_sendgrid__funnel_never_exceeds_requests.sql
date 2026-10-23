-- Delivered and processed mail can never exceed what was requested on the same day.
--
-- If this returns rows, either SendGrid changed what one of the counters means or the
-- de-duplication in staging picked an older copy of the day for one column set. Both
-- would make every rate in email_stats_daily wrong.

SELECT date, requests, processed, delivered
FROM {{ ref('core_sendgrid__email_stats_daily') }}
WHERE requests IS NOT NULL
  AND (processed > requests OR delivered > requests)
