-- core.claimlane.b2b_claim_lines
-- Every product line on every retailer-to-supplier claim, with the supplier's
-- decision grouped into a small set of outcomes.
-- Grain: claimlane_account x ticket_id x product_index.
-- Depends on: staging.claimlane.b2b_ticket, staging.claimlane.b2b_ticket_product
--
-- DECISION. Claimlane records a status per line, not per claim, because a
-- supplier can accept one product and decline another on the same claim.
-- decision groups it:
--   accepted   acceptedCredit, acceptedCreditAndRecycle, acceptedReturn,
--              acceptedReturnToSupplier, acceptedNoClaim
--   declined   declined
--   open       notHandled, or no status
--   other      other, and any status Claimlane adds later
-- acceptedNoClaim counts as accepted: the supplier agreed with the retailer,
-- even though no credit or return followed. Move it if your process disagrees.
--
-- DAYS TO DECISION IS AN UPPER BOUND. The connector syncs when a claim was
-- created and when anything on it last changed (updated_at), not when each line
-- was decided. days_to_last_update on a decided line is therefore the time to the
-- claim's latest edit, which is the decision or something after it. A comment
-- added a month later moves it. Treat it as "decided within", never as "decided
-- in".
--
-- No price is synced on B2B lines, so claims can be counted but not valued.

SELECT
    t.claimlane_account,
    t.ticket_id,
    p.product_index,
    t.rma_number,
    t.brand_id,
    t.brand_name,
    t.claim_type,
    t.retailer_name,
    t.retailer_customer_number,
    t.retailer_country,
    t.is_archived,
    DATE(t.created_at)          AS created_date,
    t.created_at,
    t.updated_at,
    p.status,
    CASE
        WHEN p.status IS NULL OR LOWER(p.status) = 'nothandled' THEN 'open'
        WHEN LOWER(p.status) = 'declined'                       THEN 'declined'
        WHEN LOWER(p.status) LIKE 'accepted%'                   THEN 'accepted'
        ELSE 'other'
    END                         AS decision,
    p.quantity,
    p.ean,
    p.serial_number,
    CASE
        WHEN p.status IS NOT NULL AND LOWER(p.status) <> 'nothandled'
        THEN TIMESTAMP_DIFF(t.updated_at, t.created_at, HOUR) / 24
    END                         AS days_to_last_update,
    -- Age of a line still waiting for a decision: the backlog number.
    CASE
        WHEN p.status IS NULL OR LOWER(p.status) = 'nothandled'
        THEN DATE_DIFF(CURRENT_DATE(), DATE(t.created_at), DAY)
    END                         AS open_age_days
FROM {{staging.claimlane.b2b_ticket}} t
INNER JOIN {{staging.claimlane.b2b_ticket_product}} p
    ON  p.claimlane_account = t.claimlane_account
    AND p.ticket_id         = t.ticket_id
