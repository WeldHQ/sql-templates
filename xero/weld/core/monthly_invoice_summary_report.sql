-- core.xero.monthly_invoice_summary_report
-- Monthly Invoice Summary Report. This template generates a monthly invoice summary
-- report from Xero, organizing the data by year and month. It details various
-- invoice metrics such as the total number and amount of invoices, total tax, total
-- amount due and paid, amount credited, and the number of unique contacts involved.
--
-- From the weld.app template library. Not reconciled against Xero;
-- check the output against the source before relying on it.

select
extract(
year
from
date
) as year
, extract(
month
from
date
) as month
, count(invoice_id) as total_invoices
, sum(sub_total) as total_sub_amount
, sum(total_tax) as total_tax_amount
, sum(total) as total_invoice_amount
, sum(amount_due) as total_amount_due
, sum(amount_paid) as total_amount_paid
, sum(amount_credited) as total_amount_credited
, count(distinct contact_contact_id) as number_of_unique_contacts
from
{{raw.xero.invoice}}
group by
1
, 2
order by
year desc
, month desc
