-- Acquisitions in the core model add up to the staging rows, per day and app, and
-- never exceed visitors. Acquisitions are a subset of visitors by Google's
-- definition, so more acquisitions than visitors means the data was misread.

WITH core AS (
    SELECT date_day, package_name,
           SUM(store_listing_acquisitions) AS acquisitions,
           SUM(store_listing_visitors)     AS visitors
    FROM {{ ref('core_google_play__store_listing_conversion') }}
    GROUP BY 1, 2
),

stg AS (
    SELECT date_day, package_name, SUM(store_listing_acquisitions) AS acquisitions
    FROM {{ ref('stg_google_play__store_performance_by_source') }}
    GROUP BY 1, 2
)

SELECT core.*, stg.acquisitions AS staging_acquisitions
FROM core
JOIN stg USING (date_day, package_name)
WHERE core.acquisitions != stg.acquisitions
   OR core.acquisitions > core.visitors
