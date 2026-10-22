-- stg_harvest__invoice
-- Thin wrapper over raw `invoice`. One row per invoice, latest version.
--
-- state is Harvest's invoice state: draft, open (sent, awaiting payment), paid or
-- closed (written off). `amount` and `due_amount` are in the invoice currency.
-- `paid_date` arrives as text and is cast here.

SELECT
    CAST(id AS STRING)                          AS invoice_id,
    CAST(number AS STRING)                      AS invoice_number,
    CAST(client_id AS STRING)                   AS client_id,
    CAST(client_name AS STRING)                 AS client_name,
    LOWER(CAST(state AS STRING))                AS state,
    UPPER(CAST(currency AS STRING))             AS currency,
    CAST(amount AS FLOAT64)                     AS amount,
    CAST(due_amount AS FLOAT64)                 AS due_amount,
    CAST(tax_amount AS FLOAT64)                 AS tax_amount,
    DATE(CAST(issue_date AS TIMESTAMP))         AS issue_date,
    DATE(CAST(due_date AS TIMESTAMP))           AS due_date,
    SAFE_CAST(CAST(paid_date AS STRING) AS DATE) AS paid_date,
    SAFE_CAST(CAST(sent_at AS STRING) AS TIMESTAMP) AS sent_at
FROM {{ source('harvest', 'invoice') }}
WHERE id IS NOT NULL
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY CAST(id AS STRING)
    ORDER BY CAST(updated_at AS TIMESTAMP) DESC, _weld_synced DESC
) = 1
