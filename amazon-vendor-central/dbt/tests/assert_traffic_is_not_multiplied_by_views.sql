-- Glance views must not be inflated by the distributor-view join.
--
-- Traffic is reported per ASIN per day, full stop - Amazon does not split it by
-- distributor view or selling program. core_amazon_vendor__sales_by_asin joins it
-- onto sales, which IS split four ways, so the same glance views legitimately appear
-- on up to four rows. Summing across them multiplies traffic and divides every
-- conversion rate by the same factor.
--
-- This test compares the total glance views in the joined model, filtered to one
-- view, against the source of truth in staging. They must match exactly. If they do
-- not, the filter in analytics__amazon_vendor_sales_by_asin is no longer sufficient -
-- typically because a new selling program appeared in the data.

WITH modelled AS (
    SELECT
        date,
        amazon_vendor,
        marketplace,
        SUM(glance_views) AS glance_views
    FROM {{ ref('core_amazon_vendor__sales_by_asin') }}
    WHERE distributor_view = 'MANUFACTURING'
      AND selling_program  = 'RETAIL'
    GROUP BY 1, 2, 3
),

source AS (
    SELECT
        date,
        amazon_vendor,
        marketplace,
        SUM(glance_views) AS glance_views
    FROM {{ ref('stg_amazon_vendor__traffic') }}
    GROUP BY 1, 2, 3
)

SELECT
    s.date,
    s.amazon_vendor,
    s.marketplace,
    s.glance_views AS source_glance_views,
    m.glance_views AS modelled_glance_views,
    COALESCE(m.glance_views, 0) - s.glance_views AS diff
FROM source s
LEFT JOIN modelled m USING (date, amazon_vendor, marketplace)
-- Modelled ABOVE source means multiplication - the bug this guards against.
-- Modelled BELOW source is expected and fine: an ASIN can have glance views with no
-- sales row to join onto, so those views drop out of the joined model.
WHERE COALESCE(m.glance_views, 0) > s.glance_views
