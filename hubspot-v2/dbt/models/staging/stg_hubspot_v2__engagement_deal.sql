-- stg_hubspot_v2__engagement_deal
-- One row per activity x associated deal, unpacked from the `deal_ids` array on
-- the engagement. Grain: engagement x deal.
--
-- An activity logged against two deals appears twice here, once per deal. That
-- is right for per-deal activity counts and wrong for totals: to count
-- activities, count engagements in staging.hubspot_v2.engagement instead.
--
-- Reads the staged engagement, so inactive (deleted) activities are already gone.

SELECT DISTINCT
    e.hubspot_portal,
    e.engagement_id,
    CAST(deal_id AS STRING)            AS deal_id,
    e.engagement_type,
    e.owner_id,
    e.occurred_at
FROM {{ ref('stg_hubspot_v2__engagement') }} e,
    UNNEST(e.deal_ids) AS deal_id
WHERE deal_id IS NOT NULL
