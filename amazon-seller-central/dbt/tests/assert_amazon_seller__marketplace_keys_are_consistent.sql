-- Every staging model must key the marketplace the same way.
--
-- THE BUG THIS EXISTS TO PREVENT, because it is silent and it breaks the flagship
-- model. Amazon identifies the marketplace three different ways depending on the
-- report: `marketplace_id` ('ATVPDKIKX0DER') in the Business Reports, listings,
-- returns and inventory; `sales_channel` ('Amazon.com') in the order report; and
-- `marketplace_name` ('Amazon.com') in the settlement report.
--
-- Those value spaces do not overlap. Every join in core is on
-- (amazon_seller, marketplace, ...) and every one of them is a LEFT or FULL OUTER
-- join, so a mismatch does not error - it just returns NULLs. Product names quietly
-- disappear from the sales model, SALE rows land under a different marketplace key
-- than their own RETURN rows so the sales equation splits across rows that never add
-- up, and asin_profitability pairs sales against no fees while the fees sit on their
-- own rows with no sales. Margin comes out looking excellent.
--
-- stg_amazon_seller__marketplace resolves the two name-based reports to the ID. This
-- test asserts the resolution actually happened everywhere, by checking that every
-- marketplace value in use is a known ID. It fires when a marketplace is missing from
-- the map (add it there) or when a new staging model emits a domain instead of an ID.

WITH known AS (
    SELECT marketplace_id FROM {{ ref('stg_amazon_seller__marketplace') }}
),

in_use AS (
    SELECT 'orders'          AS model, amazon_seller, marketplace FROM {{ ref('stg_amazon_seller__orders') }}
    UNION DISTINCT
    SELECT 'settlement',           amazon_seller, marketplace FROM {{ ref('stg_amazon_seller__settlement') }}
    UNION DISTINCT
    SELECT 'listings',             amazon_seller, marketplace FROM {{ ref('stg_amazon_seller__listings') }}
    UNION DISTINCT
    SELECT 'returns',              amazon_seller, marketplace FROM {{ ref('stg_amazon_seller__returns') }}
    UNION DISTINCT
    SELECT 'fba_inventory',        amazon_seller, marketplace FROM {{ ref('stg_amazon_seller__fba_inventory') }}
    UNION DISTINCT
    SELECT 'sales_traffic_date',   amazon_seller, marketplace FROM {{ ref('stg_amazon_seller__sales_and_traffic_by_date') }}
    UNION DISTINCT
    SELECT 'sales_traffic_asin',   amazon_seller, marketplace FROM {{ ref('stg_amazon_seller__sales_and_traffic_by_asin') }}
)

SELECT
    u.model,
    u.amazon_seller,
    u.marketplace,
    'not a known marketplace_id - add it to stg_amazon_seller__marketplace, or the model is emitting a domain instead of an ID' AS problem
FROM in_use u
LEFT JOIN known k ON k.marketplace_id = u.marketplace
WHERE u.marketplace IS NOT NULL
  AND k.marketplace_id IS NULL
