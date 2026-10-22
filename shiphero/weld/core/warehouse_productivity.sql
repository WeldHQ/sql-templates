-- core.shiphero.warehouse_productivity
-- Picks and packs per warehouse user per day, ShipHero's "picks per day" and
-- "packs per day" reports side by side.
-- Grain: day x shiphero_account x warehouse x user.
-- Depends on: staging.shiphero.pick_per_day, .pack_per_day
--
-- Picks and packs are aggregated separately and then full-outer-joined, so a user
-- who only packed on a day still has a row, with zero picks.
--
-- NOT ON A SPINE, deliberately. A user with no picks or packs on a day was usually
-- not on shift, and a row of zeros would drag down any per-user average. Sum over
-- the window you want in BI.
--
-- Units per hour cannot be computed: the logs carry event times, not shift hours.
-- first_activity_at and last_activity_at bound the working span per user per day
-- as a rough proxy.
--
-- The warehouse and order ids in these logs are not joined to shipments or orders
-- here; the pick and pack logs are reported on their own.

WITH picks AS (
    SELECT
        DATE(picked_at) AS date,
        shiphero_account,
        warehouse_id,
        user_id,
        ANY_VALUE(user_name)       AS user_name,
        COUNT(*)                   AS picks,
        SUM(quantity_picked)       AS units_picked,
        COUNT(DISTINCT order_id)   AS orders_picked,
        MIN(picked_at)             AS first_pick_at,
        MAX(picked_at)             AS last_pick_at
    FROM {{staging.shiphero.pick_per_day}}
    WHERE picked_at IS NOT NULL
    GROUP BY 1, 2, 3, 4
),

packs AS (
    SELECT
        DATE(packed_at) AS date,
        shiphero_account,
        warehouse_id,
        user_id,
        ANY_VALUE(user_name)       AS user_name,
        COUNT(*)                   AS packs,
        COUNT(DISTINCT order_id)   AS orders_packed,
        SUM(total_items)           AS items_packed,
        MIN(packed_at)             AS first_pack_at,
        MAX(packed_at)             AS last_pack_at
    FROM {{staging.shiphero.pack_per_day}}
    WHERE packed_at IS NOT NULL
    GROUP BY 1, 2, 3, 4
)

SELECT
    COALESCE(pi.date, pa.date)                         AS date,
    COALESCE(pi.shiphero_account, pa.shiphero_account) AS shiphero_account,
    COALESCE(pi.warehouse_id, pa.warehouse_id)         AS warehouse_id,
    COALESCE(pi.user_id, pa.user_id)                   AS user_id,
    COALESCE(pi.user_name, pa.user_name)               AS user_name,
    COALESCE(pi.picks, 0)          AS picks,
    COALESCE(pi.units_picked, 0)   AS units_picked,
    COALESCE(pi.orders_picked, 0)  AS orders_picked,
    COALESCE(pa.packs, 0)          AS packs,
    COALESCE(pa.orders_packed, 0)  AS orders_packed,
    COALESCE(pa.items_packed, 0)   AS items_packed,
    LEAST(COALESCE(pi.first_pick_at, pa.first_pack_at), COALESCE(pa.first_pack_at, pi.first_pick_at)) AS first_activity_at,
    GREATEST(COALESCE(pi.last_pick_at, pa.last_pack_at), COALESCE(pa.last_pack_at, pi.last_pick_at))  AS last_activity_at
FROM picks pi
FULL OUTER JOIN packs pa
  ON pa.date             = pi.date
 AND pa.shiphero_account = pi.shiphero_account
 AND pa.warehouse_id IS NOT DISTINCT FROM pi.warehouse_id
 AND pa.user_id      IS NOT DISTINCT FROM pi.user_id
