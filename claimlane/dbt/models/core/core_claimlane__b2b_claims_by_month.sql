-- core_claimlane__b2b_claims_by_month
-- Retailer claims per brand and claim type per month: volume, the supplier's
-- decisions, and the acceptance rate.
-- Grain: month x claimlane_account x brand_name x claim_type.
-- Depends on: core.claimlane.b2b_claim_lines
--
-- Counted in claim LINES and units, because decisions are per line. claims
-- counts distinct claims for context.
--
-- Lines land in the month the claim was created, whatever their decision date,
-- so recent months always carry more open lines than old ones. That is backlog,
-- not a drop in acceptance.
--
-- acceptance_rate is accepted lines over DECIDED lines (accepted + declined).
-- Open lines are left out of the denominator; counting them as not-accepted
-- makes every recent month look like a collapse. Lines with status 'other' are
-- left out too, because Claimlane does not say which way they went.
--
-- Built on a month spine per brand and claim type, from the first month the
-- combination appears to the current month.

WITH lines AS (
    SELECT
        *,
        DATE_TRUNC(created_date, MONTH)         AS month,
        COALESCE(brand_name, '(no brand)')      AS brand_label,
        COALESCE(claim_type, '(none)')          AS claim_type_label
    FROM {{ ref('core_claimlane__b2b_claim_lines') }}
    WHERE created_date IS NOT NULL
),

series AS (
    SELECT
        claimlane_account,
        brand_label,
        claim_type_label,
        MIN(month) AS first_month,
        MAX(month) AS last_month
    FROM lines
    GROUP BY 1, 2, 3
),

spine AS (
    SELECT
        s.claimlane_account,
        s.brand_label,
        s.claim_type_label,
        m AS month
    FROM series s
    CROSS JOIN UNNEST(GENERATE_DATE_ARRAY(
        s.first_month,
        GREATEST(s.last_month, DATE_TRUNC(CURRENT_DATE(), MONTH)),
        INTERVAL 1 MONTH
    )) AS m
),

monthly AS (
    SELECT
        claimlane_account,
        brand_label,
        claim_type_label,
        month,
        COUNT(DISTINCT ticket_id)              AS claims,
        COUNT(*)                               AS claim_lines,
        SUM(quantity)                          AS claimed_units,
        COUNTIF(decision = 'accepted')         AS accepted_lines,
        COUNTIF(decision = 'declined')         AS declined_lines,
        COUNTIF(decision = 'open')             AS open_lines,
        COUNTIF(decision = 'other')            AS other_lines,
        SUM(IF(decision = 'accepted', quantity, 0)) AS accepted_units,
        SUM(IF(decision = 'declined', quantity, 0)) AS declined_units
    FROM lines
    GROUP BY 1, 2, 3, 4
)

SELECT
    s.month,
    s.claimlane_account,
    s.brand_label                          AS brand_name,
    s.claim_type_label                     AS claim_type,
    COALESCE(m.claims, 0)                  AS claims,
    COALESCE(m.claim_lines, 0)             AS claim_lines,
    COALESCE(m.claimed_units, 0)           AS claimed_units,
    COALESCE(m.accepted_lines, 0)          AS accepted_lines,
    COALESCE(m.declined_lines, 0)          AS declined_lines,
    COALESCE(m.open_lines, 0)              AS open_lines,
    COALESCE(m.other_lines, 0)             AS other_lines,
    COALESCE(m.accepted_units, 0)          AS accepted_units,
    COALESCE(m.declined_units, 0)          AS declined_units,
    SAFE_DIVIDE(m.accepted_lines, m.accepted_lines + m.declined_lines) AS acceptance_rate
FROM spine s
LEFT JOIN monthly m
    ON  m.claimlane_account = s.claimlane_account
    AND m.brand_label       = s.brand_label
    AND m.claim_type_label  = s.claim_type_label
    AND m.month             = s.month
