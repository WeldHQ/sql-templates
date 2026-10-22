-- core.business_central.general_ledger
-- The general ledger: every G/L entry with its account, category and company. Recreates
-- the G/L Entries list (and the Detail Trial Balance report) in Business Central.
--
-- Grain: one row per G/L entry (company x entry number).
-- Currency: the company's local currency (LCY), named in `local_currency_code`. Entries
-- from different companies are in different currencies when the companies differ; never
-- sum across companies without converting.
-- Sign: `amount` is debit minus credit. Assets and expenses positive, liabilities, equity
-- and income negative. `amount_credit_positive` flips it for revenue-style reading.

SELECT
    e.company_id,
    c.company_name,
    c.local_currency_code,
    e.entry_number,
    e.entry_id,
    e.posting_date,
    DATE_TRUNC(e.posting_date, MONTH)       AS posting_month,
    e.document_type,
    e.document_number,
    e.description,
    e.account_id,
    e.account_number,
    a.account_name,
    a.account_category,
    a.account_subcategory,
    COALESCE(a.statement, 'unclassified')   AS statement,
    e.debit,
    e.credit,
    e.amount,
    -1 * e.amount                           AS amount_credit_positive
FROM {{staging.business_central.general_ledger_entries}} e
LEFT JOIN {{staging.business_central.accounts}} a
       ON a.company_id = e.company_id
      AND a.account_id = e.account_id
LEFT JOIN {{staging.business_central.company_information}} c
       ON c.company_id = e.company_id
