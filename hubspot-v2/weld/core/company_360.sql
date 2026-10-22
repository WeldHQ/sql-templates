-- core.hubspot_v2.company_360
-- One row per company: firmographics, owner, contacts, open and won pipeline, and
-- last touch. Grain: one row per company. Money: the portal's home currency.
-- Depends on: staging.hubspot_v2.company, .contact, .owner,
--             core.hubspot_v2.deal_pipeline
--
-- Deals are counted against the ONE company deal_pipeline assigns them to (the
-- primary association), so summing any deal column over all companies gives the
-- same total as summing deal_pipeline. Deals with no associated company appear in
-- no row here; deal_pipeline has them with company_id NULL.
--
-- Contacts are counted by HubSpot's primary company property on the contact, for
-- the same reason.

WITH deals AS (
    SELECT
        hubspot_portal,
        company_id,
        COUNT(*)                              AS deals_total,
        COUNTIF(is_open)                      AS deals_open,
        COUNTIF(is_won)                       AS deals_won,
        COUNTIF(is_lost)                      AS deals_lost,
        SUM(open_amount)                      AS open_amount,
        SUM(weighted_open_amount)             AS weighted_open_amount,
        SUM(won_amount)                       AS won_amount,
        MIN(CASE WHEN is_won THEN close_date END) AS first_won_date,
        MAX(CASE WHEN is_won THEN close_date END) AS last_won_date,
        MAX(created_date)                     AS last_deal_created_date
    FROM {{core.hubspot_v2.deal_pipeline}}
    WHERE company_id IS NOT NULL
    GROUP BY 1, 2
),

contacts AS (
    SELECT
        hubspot_portal,
        associated_company_id AS company_id,
        COUNT(*)              AS contacts,
        MAX(last_contacted_at) AS last_contact_contacted_at
    FROM {{staging.hubspot_v2.contact}}
    WHERE associated_company_id IS NOT NULL
    GROUP BY 1, 2
)

SELECT
    c.hubspot_portal,
    c.company_id,
    c.company_name,
    c.domain,
    c.industry,
    c.country,
    c.number_of_employees,
    c.lifecycle_stage,
    c.company_type,
    c.parent_company_id,
    c.original_source,
    c.created_at,

    c.owner_id,
    o.owner_name,
    o.owner_email,
    o.owner_is_active,

    COALESCE(ct.contacts, 0)          AS contacts,

    COALESCE(d.deals_total, 0)        AS deals_total,
    COALESCE(d.deals_open, 0)         AS deals_open,
    COALESCE(d.deals_won, 0)          AS deals_won,
    COALESCE(d.deals_lost, 0)         AS deals_lost,
    COALESCE(d.open_amount, 0)        AS open_amount,
    COALESCE(d.weighted_open_amount, 0) AS weighted_open_amount,
    COALESCE(d.won_amount, 0)         AS won_amount,
    d.first_won_date,
    d.last_won_date,
    d.last_deal_created_date,
    COALESCE(d.deals_won, 0) > 0      AS is_customer_by_deals,

    -- Last touch: HubSpot's own company-level roll-up, or the latest contacted date
    -- across the company's contacts if that is later.
    CASE
        WHEN c.last_contacted_at IS NULL THEN ct.last_contact_contacted_at
        WHEN ct.last_contact_contacted_at IS NULL THEN c.last_contacted_at
        ELSE GREATEST(c.last_contacted_at, ct.last_contact_contacted_at)
    END                               AS last_contacted_at,
    c.last_activity_at,
    c.next_activity_at
FROM {{staging.hubspot_v2.company}} c
LEFT JOIN {{staging.hubspot_v2.owner}} o
       ON o.hubspot_portal = c.hubspot_portal
      AND o.owner_id       = c.owner_id
LEFT JOIN deals d
       ON d.hubspot_portal = c.hubspot_portal
      AND d.company_id     = c.company_id
LEFT JOIN contacts ct
       ON ct.hubspot_portal = c.hubspot_portal
      AND ct.company_id     = c.company_id
