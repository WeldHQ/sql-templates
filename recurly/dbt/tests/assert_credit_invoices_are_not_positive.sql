-- Credit invoices carry zero or negative totals, and charge invoices zero or
-- positive ones.
--
-- core_recurly__billing_by_month adds charge and credit invoices together to get
-- net_billings, and core_recurly__recurring_revenue_lines nets credit lines
-- against plan charges. Both rely on Recurly signing credits negative. If this
-- fires, a credit is stored positive somewhere and every downstream net figure
-- is overstated by twice that credit.

SELECT
    invoice_id,
    invoice_type,
    currency,
    total
FROM {{ ref('stg_recurly__invoice') }}
WHERE (invoice_type = 'credit' AND total > 0)
   OR (invoice_type = 'charge' AND total < 0)
