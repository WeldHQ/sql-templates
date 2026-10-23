-- Posts published per month, summed over all months, equals the number of
-- published posts and pages in content_inventory. Both read the same rows with the
-- same filter, so a difference means one of the filters has drifted.

WITH cadence AS (
    SELECT SUM(posts_published) AS posts
    FROM {{ ref('core_wordpress__publishing_cadence') }}
),

inventory AS (
    SELECT COUNT(*) AS posts
    FROM {{ ref('core_wordpress__content_inventory') }}
)

SELECT *
FROM cadence, inventory
WHERE cadence.posts != inventory.posts
