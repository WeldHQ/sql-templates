-- core_google_search_console__site_performance_daily
-- The Search Console Performance report headline: clicks, impressions, CTR and
-- average position per site per day, plus how much of it the query tables cannot
-- see.
--
-- Grain: date_day x site. Dates are Pacific Time, as Search Console reports them.
-- Depends on: staging.google_search_console.site_analytics, .query_analytics
--
-- POSITION IS IMPRESSION-WEIGHTED. Search Console's average position is the mean
-- over impressions, so rows are combined as SUM(position x impressions) /
-- SUM(impressions). `weighted_position_sum` is kept so a BI tool can re-aggregate
-- to a week or month the same way; averaging `average_position` is wrong.
--
-- ANONYMIZED QUERIES. Google withholds rare queries from every query-level
-- table but keeps them in the property totals. `anonymized_clicks` and
-- `anonymized_impressions` are the gap between the two, which is usually a
-- large share of impressions on long-tail sites. Expect query reports to sum to
-- less than this model.

WITH site AS (
    SELECT
        date_day,
        site,
        SUM(clicks)                    AS clicks,
        SUM(impressions)               AS impressions,
        SUM(position * impressions)    AS weighted_position_sum
    FROM {{ ref('stg_google_search_console__site_analytics') }}
    GROUP BY 1, 2
),

queries AS (
    SELECT
        date_day,
        site,
        SUM(clicks)      AS clicks,
        SUM(impressions) AS impressions
    FROM {{ ref('stg_google_search_console__query_analytics') }}
    GROUP BY 1, 2
)

SELECT
    s.date_day,
    s.site,
    s.clicks,
    s.impressions,
    SAFE_DIVIDE(s.clicks, s.impressions)                     AS ctr,
    SAFE_DIVIDE(s.weighted_position_sum, s.impressions)      AS average_position,
    s.weighted_position_sum,

    COALESCE(q.clicks, 0)                                    AS query_clicks,
    COALESCE(q.impressions, 0)                               AS query_impressions,
    s.clicks - COALESCE(q.clicks, 0)                         AS anonymized_clicks,
    s.impressions - COALESCE(q.impressions, 0)               AS anonymized_impressions,
    SAFE_DIVIDE(s.impressions - COALESCE(q.impressions, 0), s.impressions) AS anonymized_impression_share
FROM site s
-- Both sides are pre-aggregated to date x site, so this join is one to one.
LEFT JOIN queries q USING (date_day, site)
