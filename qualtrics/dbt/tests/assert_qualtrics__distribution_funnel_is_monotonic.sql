-- A distribution cannot have more people finishing than starting, or more opens
-- than emails sent.
--
-- Qualtrics' totals are read at different moments for different distributions, but
-- within one distribution they come from the same read, so a violation here means
-- the stats columns were mapped wrong rather than a timing gap.

SELECT
    qualtrics_account,
    distribution_id,
    sent,
    opened,
    started,
    finished
FROM {{ ref('core_qualtrics__distribution_performance') }}
WHERE finished > started
   OR opened > sent
