-- core_grin__creator_campaign_performance
-- What each creator did on each campaign, and what it cost and returned: proposal
-- status, content posted and its reach, attributed sales, commissions, what is
-- owed to them and what their seeded products cost.
--
-- Grain: one row per grin_account x campaign x creator (contact).
-- Depends on: staging.grin.campaign, .proposal, .content, .content_stat,
--             .campaign_conversion, .campaign_payable, .contact_order,
--             .product_selection_item, .product, .product_variant, .contact
--
-- Every source is aggregated to campaign x creator in its own CTE BEFORE the
-- joins. Joining content to conversions raw would multiply revenue by the number
-- of posts.
--
-- A creator appears if they have ANY of a proposal, content, a conversion, a
-- payable or a seeding order on the campaign, so a creator who posted without a
-- proposal, or earned commission on an old code, is not dropped.
--
-- THREE CURRENCIES, NOT ONE. Read before computing a return:
--   revenue, commission   the conversion's currency (your store's); `currency`
--                         says which, and is NULL when one campaign x creator mixes
--                         currencies, in which case the sums are not meaningful.
--   payables_usd          US dollars, Grin's own conversion.
--   seeding_cost          the account currency the product costs were entered in.
-- campaign_performance only computes a cost-to-revenue ratio when these line up.

WITH proposals AS (
    -- One creator can have more than one proposal on a campaign (re-invited after
    -- a decline). Counted; each flag is TRUE if any of them reached that state.
    SELECT
        grin_account,
        campaign_id,
        contact_id,
        COUNT(*)                                   AS proposals,
        LOGICAL_OR(accepted_at IS NOT NULL)        AS is_accepted,
        LOGICAL_OR(declined_at IS NOT NULL
                   AND accepted_at IS NULL)        AS is_declined,
        LOGICAL_OR(is_agreed)                      AS is_agreed,
        LOGICAL_OR(completed_at IS NOT NULL OR is_complete) AS is_completed,
        SUM(IF(accepted_at IS NOT NULL, price, 0)) AS agreed_fee,
        MIN(created_at)                            AS first_proposed_at,
        MIN(accepted_at)                           AS accepted_at
    FROM {{ ref('stg_grin__proposal') }}
    WHERE campaign_id IS NOT NULL AND contact_id IS NOT NULL
    GROUP BY 1, 2, 3
),

content AS (
    SELECT
        c.grin_account,
        c.campaign_id,
        c.contact_id,
        COUNT(*)                                   AS posts,
        COUNTIF(c.is_story)                        AS stories,
        MIN(c.posted_at)                           AS first_posted_at,
        MAX(c.posted_at)                           AS last_posted_at,
        SUM(s.impressions)                         AS impressions,
        SUM(s.reach)                               AS reach,
        SUM(s.views)                               AS views,
        SUM(s.likes)                               AS likes,
        SUM(s.comments)                            AS comments,
        SUM(s.shares)                              AS shares,
        SUM(s.engagements)                         AS engagements,
        SUM(s.imv)                                 AS imv
    FROM {{ ref('stg_grin__content') }} c
    -- content_stat is one row per content after staging, so this cannot fan out.
    LEFT JOIN {{ ref('stg_grin__content_stat') }} s
        ON  s.grin_account = c.grin_account
        AND s.content_id   = c.content_id
    WHERE c.campaign_id IS NOT NULL AND c.contact_id IS NOT NULL
    GROUP BY 1, 2, 3
),

conversions AS (
    SELECT
        grin_account,
        campaign_id,
        contact_id,
        COUNTIF(NOT is_voided)                                   AS conversions,
        COUNTIF(is_voided)                                       AS voided_conversions,
        SUM(IF(NOT is_voided, amount, 0))                        AS revenue,
        SUM(IF(NOT is_voided, commission_amount, 0))             AS commission,
        IF(COUNT(DISTINCT currency) = 1, ANY_VALUE(currency), NULL) AS currency
    FROM {{ ref('stg_grin__campaign_conversion') }}
    WHERE contact_id IS NOT NULL
    GROUP BY 1, 2, 3
),

payables AS (
    SELECT
        grin_account,
        campaign_id,
        contact_id,
        SUM(IF(NOT is_voided, usd_amount, 0))                          AS payables_usd,
        SUM(IF(NOT is_voided AND payment_id IS NOT NULL, usd_amount, 0)) AS payables_in_payment_usd
    FROM {{ ref('stg_grin__campaign_payable') }}
    WHERE contact_id IS NOT NULL
    GROUP BY 1, 2, 3
),

seeding_selection AS (
    -- An order is placed per product selection, but one selection can be split
    -- across more than one store order. Distinct selections per campaign, so split
    -- shipments do not count the products twice.
    SELECT DISTINCT grin_account, campaign_id, contact_id, product_selection_id
    FROM {{ ref('stg_grin__contact_order') }}
    WHERE campaign_id IS NOT NULL AND contact_id IS NOT NULL
      AND product_selection_id IS NOT NULL
),

seeding AS (
    SELECT
        ss.grin_account,
        ss.campaign_id,
        ss.contact_id,
        COUNT(DISTINCT ss.product_selection_id)                  AS seeding_orders,
        COUNT(i.item_id)                                         AS seeded_units,
        -- Variant values first, product values as the fallback. Product cost
        -- only; shipping is shown separately because many brands ship from stock
        -- they already pay to move.
        SUM(COALESCE(v.cost, p.cost))                            AS seeding_product_cost,
        SUM(COALESCE(v.shipping_cost, p.shipping_cost))          AS seeding_shipping_cost,
        SUM(COALESCE(v.price, p.price))                          AS seeding_retail_value
    FROM seeding_selection ss
    LEFT JOIN {{ ref('stg_grin__product_selection_item') }} i
        ON  i.grin_account         = ss.grin_account
        AND i.product_selection_id = ss.product_selection_id
    LEFT JOIN {{ ref('stg_grin__product_variant') }} v
        ON  v.grin_account = i.grin_account
        AND v.variant_id   = i.variant_id
    LEFT JOIN {{ ref('stg_grin__product') }} p
        ON  p.grin_account = i.grin_account
        AND p.product_id   = i.product_id
    GROUP BY 1, 2, 3
),

creator_campaign AS (
    SELECT grin_account, campaign_id, contact_id FROM proposals
    UNION DISTINCT SELECT grin_account, campaign_id, contact_id FROM content
    UNION DISTINCT SELECT grin_account, campaign_id, contact_id FROM conversions
    UNION DISTINCT SELECT grin_account, campaign_id, contact_id FROM payables
    UNION DISTINCT SELECT grin_account, campaign_id, contact_id FROM seeding
)

SELECT
    k.grin_account,
    k.campaign_id,
    cp.campaign_name,
    k.contact_id,
    ct.contact_name                               AS creator_name,
    ct.total_reach                                AS creator_total_reach,

    COALESCE(pr.proposals, 0)                     AS proposals,
    COALESCE(pr.is_accepted, FALSE)               AS is_accepted,
    COALESCE(pr.is_declined, FALSE)               AS is_declined,
    COALESCE(pr.is_agreed, FALSE)                 AS is_agreed,
    COALESCE(pr.is_completed, FALSE)              AS is_completed,
    pr.agreed_fee,
    pr.first_proposed_at,
    pr.accepted_at,

    COALESCE(co.posts, 0)                         AS posts,
    COALESCE(co.stories, 0)                       AS stories,
    co.first_posted_at,
    co.last_posted_at,
    COALESCE(co.impressions, 0)                   AS impressions,
    COALESCE(co.reach, 0)                         AS reach,
    COALESCE(co.views, 0)                         AS views,
    COALESCE(co.likes, 0)                         AS likes,
    COALESCE(co.comments, 0)                      AS comments,
    COALESCE(co.shares, 0)                        AS shares,
    COALESCE(co.engagements, 0)                   AS engagements,
    COALESCE(co.imv, 0)                           AS imv,

    COALESCE(cv.conversions, 0)                   AS conversions,
    COALESCE(cv.voided_conversions, 0)            AS voided_conversions,
    COALESCE(cv.revenue, 0)                       AS revenue,
    COALESCE(cv.commission, 0)                    AS commission,
    cv.currency,

    COALESCE(pa.payables_usd, 0)                  AS payables_usd,
    COALESCE(pa.payables_in_payment_usd, 0)       AS payables_in_payment_usd,

    COALESCE(se.seeding_orders, 0)                AS seeding_orders,
    COALESCE(se.seeded_units, 0)                  AS seeded_units,
    COALESCE(se.seeding_product_cost, 0)          AS seeding_product_cost,
    COALESCE(se.seeding_shipping_cost, 0)         AS seeding_shipping_cost,
    COALESCE(se.seeding_retail_value, 0)          AS seeding_retail_value
FROM creator_campaign k
LEFT JOIN {{ ref('stg_grin__campaign') }} cp
    ON  cp.grin_account = k.grin_account AND cp.campaign_id = k.campaign_id
LEFT JOIN {{ ref('stg_grin__contact') }} ct
    ON  ct.grin_account = k.grin_account AND ct.contact_id = k.contact_id
LEFT JOIN proposals pr
    ON  pr.grin_account = k.grin_account AND pr.campaign_id = k.campaign_id AND pr.contact_id = k.contact_id
LEFT JOIN content co
    ON  co.grin_account = k.grin_account AND co.campaign_id = k.campaign_id AND co.contact_id = k.contact_id
LEFT JOIN conversions cv
    ON  cv.grin_account = k.grin_account AND cv.campaign_id = k.campaign_id AND cv.contact_id = k.contact_id
LEFT JOIN payables pa
    ON  pa.grin_account = k.grin_account AND pa.campaign_id = k.campaign_id AND pa.contact_id = k.contact_id
LEFT JOIN seeding se
    ON  se.grin_account = k.grin_account AND se.campaign_id = k.campaign_id AND se.contact_id = k.contact_id
