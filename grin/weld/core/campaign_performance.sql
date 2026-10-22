-- core.grin.campaign_performance
-- One row per campaign: the creator funnel, the content it produced, the sales it
-- drove and what it cost. Grin's campaign report, with the costs on the same row.
--
-- Grain: one row per grin_account x campaign.
-- Depends on: staging.grin.campaign, .campaign_conversion,
--             core.grin.creator_campaign_performance
--
-- Rolled up from creator_campaign_performance, so the two always agree; every
-- campaign is kept, including ones with no activity yet.
--
-- RATES ARE RATIOS OF SUMS: engagement rate is total engagements over total reach,
-- not the average of each post's rate, so one viral post on a small account cannot
-- dominate the campaign figure.
--
-- RETURN IS ONLY COMPUTED WHEN THE CURRENCIES MATCH. Revenue is in the store's
-- currency, payables in US dollars. revenue_per_payable_usd is filled only when the
-- campaign's conversions are all in USD. Seeding cost is in the currency product
-- costs were entered in and is left out of the ratio; add it yourself once you
-- know which currency that is.

WITH rollup AS (
    SELECT
        grin_account,
        campaign_id,
        COUNT(*)                                   AS creators,
        COUNTIF(proposals > 0)                     AS creators_proposed,
        COUNTIF(is_accepted)                       AS creators_accepted,
        COUNTIF(is_declined AND NOT is_accepted)   AS creators_declined,
        COUNTIF(is_completed)                      AS creators_completed,
        COUNTIF(posts > 0)                         AS creators_posted,
        COUNTIF(conversions > 0)                   AS creators_with_sales,
        SUM(agreed_fee)                            AS agreed_fees,
        SUM(posts)                                 AS posts,
        SUM(stories)                               AS stories,
        SUM(impressions)                           AS impressions,
        SUM(reach)                                 AS reach,
        SUM(views)                                 AS views,
        SUM(engagements)                           AS engagements,
        SUM(imv)                                   AS imv,
        SUM(conversions)                           AS conversions,
        SUM(voided_conversions)                    AS voided_conversions,
        SUM(revenue)                               AS revenue,
        SUM(commission)                            AS commission,
        SUM(payables_usd)                          AS payables_usd,
        SUM(payables_in_payment_usd)               AS payables_in_payment_usd,
        SUM(seeding_orders)                        AS seeding_orders,
        SUM(seeded_units)                          AS seeded_units,
        SUM(seeding_product_cost)                  AS seeding_product_cost,
        SUM(seeding_shipping_cost)                 AS seeding_shipping_cost,
        SUM(seeding_retail_value)                  AS seeding_retail_value
    FROM {{core.grin.creator_campaign_performance}}
    GROUP BY 1, 2
),

campaign_currency AS (
    -- Read from the conversions directly: a creator row with mixed currencies has
    -- a NULL currency and would hide the mix if this were rolled up instead.
    SELECT
        grin_account,
        campaign_id,
        IF(COUNT(DISTINCT currency) = 1, ANY_VALUE(currency), NULL) AS currency,
        COUNT(DISTINCT currency)                                    AS currencies
    FROM {{staging.grin.campaign_conversion}}
    WHERE NOT is_voided
    GROUP BY 1, 2
)

SELECT
    c.grin_account,
    c.campaign_id,
    c.campaign_name,
    c.campaign_public_name,
    c.budget,
    c.compensation,
    c.proposals_start_at,
    c.proposals_end_at,
    c.content_start_at,
    c.content_end_at,
    c.created_at,

    COALESCE(r.creators, 0)                AS creators,
    COALESCE(r.creators_proposed, 0)       AS creators_proposed,
    COALESCE(r.creators_accepted, 0)       AS creators_accepted,
    COALESCE(r.creators_declined, 0)       AS creators_declined,
    COALESCE(r.creators_completed, 0)      AS creators_completed,
    COALESCE(r.creators_posted, 0)         AS creators_posted,
    COALESCE(r.creators_with_sales, 0)     AS creators_with_sales,
    COALESCE(r.agreed_fees, 0)             AS agreed_fees,

    COALESCE(r.posts, 0)                   AS posts,
    COALESCE(r.stories, 0)                 AS stories,
    COALESCE(r.impressions, 0)             AS impressions,
    COALESCE(r.reach, 0)                   AS reach,
    COALESCE(r.views, 0)                   AS views,
    COALESCE(r.engagements, 0)             AS engagements,
    COALESCE(r.imv, 0)                     AS imv,
    SAFE_DIVIDE(r.engagements, r.reach)    AS engagement_rate_by_reach,

    COALESCE(r.conversions, 0)             AS conversions,
    COALESCE(r.voided_conversions, 0)      AS voided_conversions,
    COALESCE(r.revenue, 0)                 AS revenue,
    COALESCE(r.commission, 0)              AS commission,
    cc.currency,
    COALESCE(cc.currencies, 0)             AS revenue_currencies,
    SAFE_DIVIDE(r.revenue, r.conversions)  AS average_order_value,

    COALESCE(r.payables_usd, 0)            AS payables_usd,
    COALESCE(r.payables_in_payment_usd, 0) AS payables_in_payment_usd,
    SAFE_DIVIDE(r.payables_usd, r.engagements)          AS payables_usd_per_engagement,
    SAFE_DIVIDE(r.payables_usd * 1000, r.impressions)   AS payables_usd_per_thousand_impressions,
    IF(cc.currency = 'USD', SAFE_DIVIDE(r.revenue, r.payables_usd), NULL)
                                           AS revenue_per_payable_usd,

    COALESCE(r.seeding_orders, 0)          AS seeding_orders,
    COALESCE(r.seeded_units, 0)            AS seeded_units,
    COALESCE(r.seeding_product_cost, 0)    AS seeding_product_cost,
    COALESCE(r.seeding_shipping_cost, 0)   AS seeding_shipping_cost,
    COALESCE(r.seeding_retail_value, 0)    AS seeding_retail_value
FROM {{staging.grin.campaign}} c
LEFT JOIN rollup r
    ON  r.grin_account = c.grin_account AND r.campaign_id = c.campaign_id
LEFT JOIN campaign_currency cc
    ON  cc.grin_account = c.grin_account AND cc.campaign_id = c.campaign_id
