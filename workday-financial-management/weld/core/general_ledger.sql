-- core.workday_financial_management.general_ledger
-- Every line of every posted journal entry, with its ledger account and the
-- account's classification.
--
-- Grain: journal entry x line index.
--
-- Included: journals whose status is Posted. Draft, in-progress and cancelled
-- journals are left out. A cancelled posted journal is undone in Workday by a
-- posted reversing journal, so both stay in and net to zero.
--
-- Currency: ledger_debit, ledger_credit and everything derived from them are in
-- the ledger currency, the base currency of the line's company (company_currency).
-- debit and credit are kept in the transaction currency (line_currency) for
-- reference. Do not sum ledger amounts across companies with different currencies.
--
-- Signs:
--   ledger_debit, ledger_credit   both positive
--   net_debit                     ledger_debit - ledger_credit; sums to zero over
--                                 each journal and company
--   amount_natural                signed by the account's normal balance:
--                                 debit-positive for Asset and Expense,
--                                 credit-positive for Liability, Equity and
--                                 Revenue. Unclassified accounts are treated as
--                                 debit-positive; fix the mapping in
--                                 staging.workday_financial_management.ledger_account.

WITH posted AS (
    SELECT *
    FROM {{staging.workday_financial_management.journal_entry}}
    WHERE LOWER(journal_status) = 'posted'
)

SELECT
    l.workday_tenant,
    COALESCE(l.line_company_id, j.company_id)          AS company_id,
    c.company_name,
    c.company_currency,
    j.ledger_id,
    j.ledger_name,
    j.book_code,
    j.accounting_date,
    DATE_TRUNC(j.accounting_date, MONTH)               AS accounting_month,
    j.ledger_period,
    j.journal_source,
    l.journal_entry_id,
    j.journal_number,
    l.line_index,
    l.journal_line_number,
    COALESCE(l.memo, j.memo)                           AS memo,
    COALESCE(l.account_set_code, j.account_set_code)   AS account_set_code,
    l.ledger_account_code,
    COALESCE(la.ledger_account_name, l.ledger_account_name) AS ledger_account_name,
    la.ledger_account_type,
    la.classification,
    COALESCE(la.classification IN ('Revenue', 'Expense'), FALSE) AS is_profit_and_loss,
    l.line_currency,
    l.debit,
    l.credit,
    l.ledger_debit,
    l.ledger_credit,
    l.ledger_debit - l.ledger_credit                   AS net_debit,
    CASE
        WHEN la.classification IN ('Liability', 'Equity', 'Revenue') THEN l.ledger_credit - l.ledger_debit
        ELSE l.ledger_debit - l.ledger_credit
    END                                                AS amount_natural
FROM {{staging.workday_financial_management.journal_entry_line}} l
-- One header per journal, one account set per code, one ledger account per set
-- and identifier, one company per id: none of these joins can add rows.
JOIN posted j
    ON  j.workday_tenant   = l.workday_tenant
    AND j.journal_entry_id = l.journal_entry_id
LEFT JOIN {{staging.workday_financial_management.account_set}} s
    ON  s.workday_tenant   = l.workday_tenant
    AND s.account_set_code = COALESCE(l.account_set_code, j.account_set_code)
LEFT JOIN {{staging.workday_financial_management.ledger_account}} la
    ON  la.workday_tenant      = l.workday_tenant
    AND la.account_set_wid     = s.account_set_wid
    AND la.ledger_account_code = l.ledger_account_code
LEFT JOIN {{staging.workday_financial_management.company}} c
    ON  c.workday_tenant = l.workday_tenant
    AND c.company_id     = COALESCE(l.line_company_id, j.company_id)
