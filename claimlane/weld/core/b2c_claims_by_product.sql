-- core.claimlane.b2c_claims_by_product
-- Which products come back, why, and what they cost in refunds.
-- Grain: claimlane_account x organization_id x currency x product_sku x issue_tag.
-- All time, with a last-90-days column so a fixed problem does not stay on top.
-- Depends on: core.claimlane.b2c_claim_lines
--
-- Keyed on SKU, falling back to product_id when a shop sends no SKU, because a
-- product's name changes and its SKU usually does not. product_name is the most
-- recent name seen for the key.
--
-- WHAT THIS CANNOT GIVE YOU: a return RATE. Claimlane only knows the products
-- that were claimed, not the ones that were sold. Divide claimed_quantity by
-- units sold from your shop platform, on the same SKU, to get one.
--
-- issue_tag values are configured per Claimlane account and kept as text.
-- Lines without a reason are grouped under '(none)' rather than dropped.

WITH lines AS (
    SELECT
        *,
        COALESCE(product_sku, product_id, '(unknown product)') AS product_key
    FROM {{core.claimlane.b2c_claim_lines}}
)

SELECT
    claimlane_account,
    organization_id,
    currency,
    product_key                                           AS product_sku,
    ARRAY_AGG(product_name IGNORE NULLS ORDER BY created_at DESC LIMIT 1)[SAFE_OFFSET(0)]
                                                          AS product_name,
    COALESCE(issue_tag, '(none)')                         AS issue_tag,
    COUNT(DISTINCT ticket_id)                             AS tickets,
    SUM(claimed_quantity)                                 AS claimed_quantity,
    SUM(claimed_value)                                    AS claimed_value,
    SUM(refunded_quantity)                                AS refunded_quantity,
    SUM(refunded_amount)                                  AS refunded_amount,
    SAFE_DIVIDE(SUM(refunded_amount), SUM(claimed_value)) AS refund_rate_of_claimed_value,
    SUM(IF(created_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY), claimed_quantity, 0))
                                                          AS claimed_quantity_last_90_days,
    AVG(days_from_order_to_claim)                         AS avg_days_from_order_to_claim,
    MIN(created_date)                                     AS first_claim_date,
    MAX(created_date)                                     AS last_claim_date
FROM lines
GROUP BY claimlane_account, organization_id, currency, product_key, COALESCE(issue_tag, '(none)')
