-- staging.business_central.general_ledger_entries
-- Thin wrapper over raw `general_ledger_entry`: one row per G/L entry, per company.
--
-- Amounts are in the company's local currency (LCY), whatever currency the source
-- document was in. Business Central stores debit and credit as two non-negative
-- columns; `amount` is debit minus credit, so debits are positive, credits negative and
-- the whole ledger of a company sums to zero.
--
-- Entry numbers are unique within a company, not across companies, so `company_id` is
-- part of every key.

SELECT
    company_id,
    id                                                   AS entry_id,
    entry_number,
    SAFE.PARSE_DATE('%Y-%m-%d', SUBSTR(posting_date, 1, 10)) AS posting_date,
    document_number,
    NULLIF(TRIM(document_type), '')                      AS document_type,
    account_id,
    account_number,
    description,
    CAST(COALESCE(debit_amount, 0) AS NUMERIC)           AS debit,
    CAST(COALESCE(credit_amount, 0) AS NUMERIC)          AS credit,
    CAST(COALESCE(debit_amount, 0) AS NUMERIC)
        - CAST(COALESCE(credit_amount, 0) AS NUMERIC)    AS amount,
    CAST(last_modified_date_time AS TIMESTAMP)           AS last_modified_at
FROM {{raw.business_central.general_ledger_entry}}
WHERE id IS NOT NULL
-- Incremental on lastModifiedDateTime with an overlap window; keep the latest copy.
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY company_id, id
    ORDER BY last_modified_date_time DESC, _weld_synced DESC
) = 1
