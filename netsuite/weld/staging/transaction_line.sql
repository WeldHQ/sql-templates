-- staging.netsuite.transaction_line
-- Transaction lines: the subsidiary and the reporting dimensions (department,
-- class, location) that the accounting line does not carry.
--
-- Grain: transaction x line. mainline is TRUE for the header line of each
-- transaction (the receivable or payable side on invoices and bills).
--
-- Single NetSuite account. To add another, UNION ALL a second block below pointing
-- at that account's connector with a different netsuite_account label.

SELECT
    'account_1'                                AS netsuite_account,
    CAST(transaction AS STRING)                AS transaction_id,
    CAST(id AS STRING)                         AS transaction_line_id,
    CAST(subsidiary AS STRING)                 AS subsidiary_id,
    CAST(department AS STRING)                 AS department_id,
    CAST(class AS STRING)                      AS class_id,
    CAST(location AS STRING)                   AS location_id,
    CAST(entity AS STRING)                     AS entity_id,
    NULLIF(TRIM(CAST(memo AS STRING)), '')     AS line_memo,
    COALESCE(CAST(mainline AS BOOL), FALSE)    AS is_main_line,
    COALESCE(CAST(taxline AS BOOL), FALSE)     AS is_tax_line
FROM {{raw.netsuite.transactionline}}
