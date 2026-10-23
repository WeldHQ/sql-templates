-- Every counted order's parsed product lines must add back up to Commerce Cloud's
-- own product_sub_total. A failure means product_items did not parse for that
-- order: usually the JSON key names differ from the paths in
-- stg_salesforce_commerce_cloud__order_product_item, or the column is empty.
--
-- Returns zero rows when every order parses. A cent of tolerance absorbs rounding.

SELECT sfcc_instance, order_no, unparsed_line_amount
FROM {{ ref('core_salesforce_commerce_cloud__sales_over_time') }}
WHERE ABS(COALESCE(unparsed_line_amount, 0)) > 0.01
   OR gross_sales IS NULL
