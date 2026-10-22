-- core.business_central.profit_and_loss_by_month
-- Income statement by month, at account level with Business Central's account category
-- (Income, Cost of Goods Sold, Expense) and subcategory alongside for roll-up in BI.
--
-- Grain: one row per company x month x account, income statement accounts only.
-- Currency: the company's local currency (LCY).
-- Sign: `amount` is credit positive, the way an income statement reads: income positive,
-- costs negative, and SUM(amount) is the result for the period.
--
-- Closing entries. When a fiscal year is closed, Business Central posts entries that
-- move every income statement balance to retained earnings, dated on the last day of the
-- year. They would make that month's result zero, so list the document numbers your
-- company used for them in `closing_documents` below and they are excluded. Business
-- Central marks these entries with a closing date internally, but the API returns them
-- with an ordinary posting date, so the document number is the reliable handle.

WITH closing_documents AS (
    -- One row per (company_id, document_number) used by "Close Income Statement".
    -- Empty by default. Example:
    --   SELECT 'your-company-id' AS company_id, 'CLOSE2025' AS document_number
    SELECT CAST(NULL AS STRING) AS company_id, CAST(NULL AS STRING) AS document_number
    FROM UNNEST([1])
    WHERE FALSE
)

SELECT
    gl.company_id,
    gl.company_name,
    gl.local_currency_code,
    gl.posting_month                       AS month,
    gl.account_category,
    gl.account_subcategory,
    gl.account_id,
    gl.account_number,
    gl.account_name,
    SUM(gl.debit)                          AS debit,
    SUM(gl.credit)                         AS credit,
    SUM(gl.amount_credit_positive)         AS amount,
    COUNT(*)                               AS entries
FROM {{core.business_central.general_ledger}} gl
LEFT JOIN closing_documents cd
       ON cd.company_id      = gl.company_id
      AND cd.document_number = gl.document_number
WHERE gl.statement = 'income_statement'
  AND cd.document_number IS NULL
GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9
