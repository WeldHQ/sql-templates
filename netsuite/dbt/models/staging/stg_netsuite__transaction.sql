-- stg_netsuite__transaction
-- Transaction headers: type, number, dates, counterparty, currency, open amount.
--
-- Grain: one row per transaction.
--
-- type is NetSuite's short code (CustInvc, VendBill, Journal, CustPymt, ...);
-- recordtype is the long record name (invoice, vendorbill, journalentry, ...) and
-- is what the deletion log keys on. foreign* amounts are in the transaction's own
-- currency; exchange_rate converts them to the subsidiary's base currency.
--
-- Single NetSuite account. To add another, UNION ALL a second block below pointing
-- at that account's connector with a different netsuite_account label.

SELECT
    'account_1'                                     AS netsuite_account,
    CAST(id AS STRING)                              AS transaction_id,
    CAST(type AS STRING)                            AS transaction_type,
    LOWER(CAST(recordtype AS STRING))               AS record_type,
    CAST(tranid AS STRING)                          AS document_number,
    CAST(trandate AS DATE)                          AS transaction_date,
    CAST(duedate AS DATE)                           AS due_date,
    CAST(postingperiod AS STRING)                   AS posting_period_id,
    CAST(entity AS STRING)                          AS entity_id,
    CAST(currency AS STRING)                        AS currency_id,
    CAST(exchangerate AS NUMERIC)                   AS exchange_rate,
    CAST(foreigntotal AS NUMERIC)                   AS foreign_total,
    CAST(foreignamountunpaid AS NUMERIC)            AS foreign_amount_unpaid,
    CAST(status AS STRING)                          AS status,
    NULLIF(TRIM(CAST(memo AS STRING)), '')          AS memo,
    COALESCE(CAST(posting AS BOOL), FALSE)          AS is_posting,
    COALESCE(CAST(voided AS BOOL), FALSE)           AS is_voided
FROM {{ source('netsuite', 'transaction') }}
