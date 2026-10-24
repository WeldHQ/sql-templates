-- Each invoice's lines must add up to its total excluding VAT. Invoices without any
-- synced lines are skipped. A cent of tolerance absorbs rounding.
-- Returns zero rows when they agree.

SELECT advertiser_id, invoice_number, amount_excl_vat, lines_amount_excl_vat
FROM {{ ref('core_daisycon__invoices') }}
WHERE line_count > 0
  AND ABS(COALESCE(amount_excl_vat, 0) - COALESCE(lines_amount_excl_vat, 0)) > 0.01
