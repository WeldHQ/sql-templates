-- staging.workday_financial_management.journal_entry
-- Journal entry headers from Workday's Get_Journals: status, company, ledger,
-- accounting date and period.
--
-- Grain: one row per journal entry.
--
-- Reference fields arrive in three columns: *_id is the Workday WID, *_code is
-- the reference's other ID (the one people recognise, such as a company code),
-- and *_descriptor is the display name. Status is filtered in core on its code,
-- with the descriptor as a fallback: the WID differs per tenant, and the
-- descriptor is translated in tenants that do not run in English.
--
-- Single tenant. To add another, UNION ALL a second block below pointing at that
-- tenant's connector with a different workday_tenant label.

SELECT
    'tenant_1'                                       AS workday_tenant,
    CAST(id AS STRING)                               AS journal_entry_id,
    CAST(journal_number AS STRING)                   AS journal_number,
    DATE(CAST(accounting_date AS TIMESTAMP))         AS accounting_date,
    CAST(journal_status_descriptor AS STRING)        AS journal_status,
    CAST(journal_status_code AS STRING)              AS journal_status_code,
    CAST(company_id AS STRING)                       AS company_id,
    CAST(company_descriptor AS STRING)               AS company_name,
    CAST(ledger_id AS STRING)                        AS ledger_id,
    CAST(ledger_descriptor AS STRING)                AS ledger_name,
    CAST(book_code_descriptor AS STRING)             AS book_code,
    CAST(ledger_period_descriptor AS STRING)         AS ledger_period,
    CAST(journal_source_descriptor AS STRING)        AS journal_source,
    CAST(display_account_set_code AS STRING)         AS account_set_code,
    UPPER(CAST(currency_code AS STRING))             AS journal_currency,
    NULLIF(TRIM(CAST(memo AS STRING)), '')           AS memo
FROM {{raw.workday_financial_management.journal_entry}}
