-- staging.grin.content_stat
-- Thin wrapper over raw `content_stat`: the latest performance numbers for one
-- piece of content, as Grin last collected them from the network. One row per
-- content.
--
-- CURRENT STATE, not a time series: Grin overwrites these as it re-polls the
-- network, so the numbers for an old post keep growing and there is no way to ask
-- what a post had done after seven days.
--
-- `imv` is Grin's media value estimate for the post. Grin does not publish its
-- method; treat it as Grin's number, not a cost you could have paid.
-- `owner_reach` is the creator's follower count when the stats were taken.
-- engagement_rate and reply_rate are Grin's own per-post ratios; they are kept for
-- reference, but core recomputes rates from summed counts rather than averaging
-- these.
--
-- Single Grin account; see staging.grin.campaign.

SELECT
    'account_1'                          AS grin_account,
    CAST(content_id AS STRING)           AS content_id,
    CAST(owner_reach AS FLOAT64)         AS owner_reach,
    CAST(impressions AS FLOAT64)         AS impressions,
    CAST(reach AS FLOAT64)               AS reach,
    CAST(views AS FLOAT64)               AS views,
    CAST(likes AS FLOAT64)               AS likes,
    CAST(comments AS FLOAT64)            AS comments,
    CAST(shares AS FLOAT64)              AS shares,
    CAST(engagements AS FLOAT64)         AS engagements,
    CAST(engagement_rate AS FLOAT64)     AS engagement_rate,
    CAST(imv AS FLOAT64)                 AS imv,
    CAST(updated_at AS TIMESTAMP)        AS stats_updated_at
FROM {{raw.grin.content_stat}}
WHERE content_id IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY content_id ORDER BY updated_at DESC, _weld_synced DESC) = 1
