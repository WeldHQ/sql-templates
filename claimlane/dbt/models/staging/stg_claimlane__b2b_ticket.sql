-- stg_claimlane__b2b_ticket
-- Thin wrapper over raw `b2b_ticket`. One row per business claim: a retailer
-- claiming against a supplier's brand (used product, new product, return).
--
-- These are synced per supplier and only for the supplier organisations
-- selected on the connection, so a retailer-side key that sees no
-- suppliers syncs no B2B tickets.
--
-- updated_at is when anything on the ticket last changed. It is NOT a decision
-- date; see core.claimlane.b2b_claim_lines for how it is (carefully) used.

SELECT
    'account_1'                                                  AS claimlane_account,
    CAST(id AS STRING)                                           AS ticket_id,
    NULLIF(TRIM(CAST(brand_id AS STRING)), '')                   AS brand_id,
    NULLIF(TRIM(CAST(brand_name AS STRING)), '')                 AS brand_name,
    -- usedProduct, usedProductWithoutConsumer, newProduct or returnProduct.
    NULLIF(TRIM(CAST(claim_type AS STRING)), '')                 AS claim_type,
    NULLIF(TRIM(CAST(rma_number AS STRING)), '')                 AS rma_number,
    NULLIF(TRIM(CAST(retailer_company_name AS STRING)), '')      AS retailer_name,
    NULLIF(TRIM(CAST(retailer_customer_number AS STRING)), '')   AS retailer_customer_number,
    UPPER(NULLIF(TRIM(CAST(retailer_address_country AS STRING)), '')) AS retailer_country,
    CAST(is_archived_supplier AS BOOL)                           AS is_archived,
    CAST(supplier_integration_complete AS BOOL)                  AS supplier_integration_complete,
    CAST(created_at AS TIMESTAMP)                                AS created_at,
    CAST(updated_at AS TIMESTAMP)                                AS updated_at
FROM {{ source('claimlane', 'b2b_ticket') }}
