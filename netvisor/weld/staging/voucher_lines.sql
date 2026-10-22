-- staging.netvisor.voucher_lines
-- Thin wrapper over raw `accounting_ledger`, unnested to one row per voucher line.
--
-- Netvisor's accounting ledger arrives as one row per voucher with its lines in a JSON
-- array (`voucher_line`). Each element carries netvisorKey, lineSum, description,
-- accountNumber, vatPercent, vatCode, an optional accountDimension and an optional
-- dimension array. The keys inside the array keep the API's camelCase.
--
-- Amounts are in the company's accounting currency (EUR for Finnish companies).
-- `lineSum` is signed by Netvisor: debit positive, credit negative, and every valid
-- voucher sums to zero. `debit` and `credit` split it into two non-negative columns.
--
-- Voucher status is kept: Netvisor returns valid, invalidated and deleted vouchers.
-- Only valid ones belong in a balance; core filters on `voucher_status = 'valid'`.

WITH vouchers AS (
    SELECT
        netvisor_key,
        LOWER(TRIM(status))                         AS voucher_status,
        voucher_date,
        voucher_number,
        voucher_description,
        voucher_class,
        linked_source_netvisor_key_value,
        linked_source_netvisor_key_attr_type,
        voucher_netvisor_uri,
        voucher_line
    FROM {{raw.netvisor.accounting_ledger}}
    WHERE netvisor_key IS NOT NULL
    -- Incremental stream keyed on the voucher's Netvisor key; keep the latest copy.
    QUALIFY ROW_NUMBER() OVER (PARTITION BY netvisor_key ORDER BY _weld_synced DESC) = 1
),

-- One row per element of the voucher_line array, with its position on the voucher.
lines AS (
    SELECT
        v.netvisor_key,
        v.voucher_status,
        v.voucher_date,
        v.voucher_number,
        v.voucher_description,
        v.voucher_class,
        v.linked_source_netvisor_key_value,
        v.linked_source_netvisor_key_attr_type,
        v.voucher_netvisor_uri,
        voucher_line_item AS voucher_line_item,
        line_index        AS line_index
    FROM vouchers v,
         UNNEST(JSON_QUERY_ARRAY(v.voucher_line)) AS voucher_line_item WITH OFFSET AS line_index
)

SELECT
    v.netvisor_key                                                AS voucher_key,
    CAST(v.voucher_number AS INT64)                               AS voucher_number,
    COALESCE(
        SAFE.PARSE_DATE('%Y-%m-%d', SUBSTR(v.voucher_date, 1, 10)),
        SAFE.PARSE_DATE('%d.%m.%Y', v.voucher_date)
    )                                                             AS voucher_date,
    v.voucher_status,
    v.voucher_description,
    v.voucher_class,
    LOWER(v.linked_source_netvisor_key_attr_type)                 AS linked_source_type,
    v.linked_source_netvisor_key_value                            AS linked_source_key,
    v.voucher_netvisor_uri,
    line_index,
    SAFE_CAST(JSON_VALUE(voucher_line_item, '$.netvisorKey') AS INT64)   AS line_key,
    SAFE_CAST(JSON_VALUE(voucher_line_item, '$.accountNumber') AS INT64) AS account_number,
    CAST(ROUND(SAFE_CAST(JSON_VALUE(voucher_line_item, '$.lineSum') AS FLOAT64), 2) AS NUMERIC) AS amount,
    CAST(ROUND(GREATEST(SAFE_CAST(JSON_VALUE(voucher_line_item, '$.lineSum') AS FLOAT64), 0), 2) AS NUMERIC) AS debit,
    CAST(ROUND(GREATEST(-1 * SAFE_CAST(JSON_VALUE(voucher_line_item, '$.lineSum') AS FLOAT64), 0), 2) AS NUMERIC) AS credit,
    JSON_VALUE(voucher_line_item, '$.description')                AS line_description,
    SAFE_CAST(JSON_VALUE(voucher_line_item, '$.vatPercent') AS NUMERIC) AS vat_percent,
    JSON_VALUE(voucher_line_item, '$.vatCode')                    AS vat_code,
    JSON_VALUE(voucher_line_item, '$.accountDimension.value')     AS account_dimension,
    -- Cost-centre style dimensions, left as JSON: [{dimensionName, dimensionItem}, ...].
    JSON_QUERY(voucher_line_item, '$.dimension')                  AS dimensions_json
FROM lines v
