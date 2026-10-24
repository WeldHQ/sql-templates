-- Every distinct deal stage that fell through to 'Open'.
--
-- A FAILURE HERE IS INFORMATION, NOT NECESSARILY A DEFECT. Zoho has no is_won or
-- is_closed flag, so core_zoho_crm__deal_pipeline reads won and lost out of the
-- stage string with LIKE '%won%' / '%lost%'. Genuinely open stages
-- (Qualification, Negotiation/Review, ...) are supposed to appear in this list.
--
-- What you are looking for is a CLOSED stage hiding among them - "Contract
-- Signed", "Dead", "Churned", "Nurture", "Abandoned", anything in another
-- language. Every row of that kind is revenue being counted as open pipeline, or
-- a loss that never shows up in the win rate.
--
-- Run it once when you deploy, then whenever sales ops adds a stage. Add anything
-- it surfaces to the CASE in the core model.

SELECT
    stage,
    COUNT(*)     AS deals,
    SUM(amount)  AS amount,
    MIN(created_time) AS first_seen,
    MAX(created_time) AS last_seen
FROM {{ ref('core_zoho_crm__deal_pipeline') }}
WHERE stage_status = 'Open'
GROUP BY 1
ORDER BY amount DESC
