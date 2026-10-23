-- One row per day x account x currency x variant in product_sales.
--
-- A duplicate means the variant or product join fanned out, which inflates units,
-- revenue and cost by the same factor and leaves the margin percentage looking
-- plausible. That is why it needs a test rather than an eyeball check.
--
-- Returns zero rows when the grain holds.

SELECT
    date,
    traede_account,
    currency,
    variant_id,
    COUNT(*) AS row_count
FROM {{ ref('core_traede__product_sales') }}
GROUP BY 1, 2, 3, 4
HAVING COUNT(*) > 1
