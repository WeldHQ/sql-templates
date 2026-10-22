-- One row per order in sales_over_time. order_no is the stream's key, so a
-- duplicate means the same order number exists on two sites of one instance,
-- or the stream was loaded twice.

SELECT sfcc_instance, order_no, COUNT(*) AS n
FROM {{ ref('core_salesforce_commerce_cloud__sales_over_time') }}
GROUP BY 1, 2
HAVING COUNT(*) > 1
