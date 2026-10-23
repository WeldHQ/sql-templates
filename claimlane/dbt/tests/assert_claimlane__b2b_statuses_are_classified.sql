-- Every B2B line status is one b2b_claim_lines knows about.
--
-- The decision CASE sends anything unrecognised to 'other', which keeps it out of
-- the acceptance rate entirely. This lists each status that landed in 'other'
-- without literally being Claimlane's own 'other', so a new status shows up here
-- instead of quietly shrinking the denominator. Add it to the CASE in
-- core.claimlane.b2b_claim_lines.

SELECT
    status,
    COUNT(*) AS claim_lines
FROM {{ ref('core_claimlane__b2b_claim_lines') }}
WHERE decision = 'other'
  AND LOWER(status) <> 'other'
GROUP BY 1
