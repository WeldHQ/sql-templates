-- core.netvisor.general_ledger
-- The general ledger (pääkirja): every line of every valid voucher, with its account's
-- report line. Recreates the transaction list behind Netvisor's ledger reports.
--
-- Grain: one row per voucher line (voucher_key x line_index).
-- Currency: the company's accounting currency, EUR for a Finnish company.
-- Sign: `amount` is Netvisor's own line sum, debit positive and credit negative, so
-- every voucher sums to zero. `amount_credit_positive` flips it for revenue-style
-- reading.
--
-- Invalidated and deleted vouchers are excluded. No account names: Netvisor's chart of
-- accounts is not part of the synced data, so accounts are identified by number and
-- grouped through staging.netvisor.finnish_account_groups.

SELECT
    l.voucher_key,
    l.voucher_number,
    l.voucher_date,
    DATE_TRUNC(l.voucher_date, MONTH)     AS voucher_month,
    l.voucher_class,
    l.voucher_description,
    l.line_index,
    l.line_key,
    l.account_number,
    g.statement,
    g.report_line,
    g.sort_order                          AS report_line_sort_order,
    l.line_description,
    l.debit,
    l.credit,
    l.amount,
    -1 * l.amount                         AS amount_credit_positive,
    l.vat_percent,
    l.vat_code,
    l.account_dimension,
    l.dimensions_json,
    l.linked_source_type,
    l.linked_source_key
FROM {{staging.netvisor.voucher_lines}} l
-- Ranges do not overlap, so this join adds at most one group per line.
LEFT JOIN {{staging.netvisor.finnish_account_groups}} g
       ON l.account_number BETWEEN g.range_start AND g.range_end
WHERE l.voucher_status = 'valid'
