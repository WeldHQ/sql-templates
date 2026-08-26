-- zoho_crm_account_360 - one row per account, with its people, pipeline and notes.
-- Grain: account. Currency: org reporting currency.
-- Depends on: stg_zoho_crm__account, .contact, .user, .note,
--             core_zoho_crm__deal_pipeline
--
-- The account-level view the rest of the schema can actually support: who works
-- there, what is open, what has been won, and when anybody last wrote anything
-- down. This is the model to reverse-ETL back into Zoho, or to join to product
-- usage and billing data for a real customer view.
--
-- NOT IN HERE: calls, meetings and tasks. They carry no account key in this
-- connector - see core_zoho_crm__rep_activity for why. last_note_at is the closest
-- honest proxy for account engagement the connector allows, and it only reflects
-- what reps bothered to write down.

WITH contacts AS (
    SELECT
        zoho_org,
        account_id,
        COUNT(*)                                  AS contacts,
        COUNTIF(email IS NOT NULL)                AS contacts_with_email,
        MAX(created_time)                         AS last_contact_added_at
    FROM {{ ref('stg_zoho_crm__contact') }}
    WHERE account_id IS NOT NULL
    GROUP BY 1, 2
),

deals AS (
    SELECT
        zoho_org,
        account_id,
        COUNT(*)                     AS deals_total,
        COUNTIF(is_open)             AS deals_open,
        COUNTIF(is_won)              AS deals_won,
        COUNTIF(is_lost)             AS deals_lost,
        COUNTIF(is_overdue)          AS deals_overdue,
        SUM(pipeline_amount)         AS open_pipeline_amount,
        SUM(won_amount)              AS won_amount,
        SUM(lost_amount)             AS lost_amount,
        MIN(CASE WHEN is_open THEN closing_date END) AS next_expected_close,
        MAX(created_time)            AS last_deal_created_at
    FROM {{ ref('core_zoho_crm__deal_pipeline') }}
    WHERE account_id IS NOT NULL
    GROUP BY 1, 2
),

-- Notes reach an account three ways: written on the account itself, on one of its
-- deals, or on one of its contacts. Zoho ids are globally unique across modules,
-- so one join per route resolves the parent without needing $se_module.
note_targets AS (
    SELECT a.zoho_org, a.account_id, a.account_id AS target_id
    FROM {{ ref('stg_zoho_crm__account') }} a
    UNION ALL
    SELECT d.zoho_org, d.account_id, d.deal_id
    FROM {{ ref('core_zoho_crm__deal_pipeline') }} d
    WHERE d.account_id IS NOT NULL
    UNION ALL
    SELECT c.zoho_org, c.account_id, c.contact_id
    FROM {{ ref('stg_zoho_crm__contact') }} c
    WHERE c.account_id IS NOT NULL
),

notes AS (
    SELECT
        t.zoho_org,
        t.account_id,
        COUNT(*)               AS notes,
        MAX(n.created_time)    AS last_note_at
    FROM {{ ref('stg_zoho_crm__note') }} n
    JOIN note_targets t
      ON t.zoho_org  = n.zoho_org
     AND t.target_id = n.parent_id
    GROUP BY 1, 2
)

SELECT
    a.zoho_org,
    a.account_id,
    a.account_name,
    a.industry,
    a.website,
    a.phone,
    a.created_time AS account_created_time,

    a.owner_id,
    u.full_name AS owner_name,
    u.email     AS owner_email,
    u.is_active AS owner_is_active,

    COALESCE(c.contacts, 0)            AS contacts,
    COALESCE(c.contacts_with_email, 0) AS contacts_with_email,

    COALESCE(d.deals_total, 0)         AS deals_total,
    COALESCE(d.deals_open, 0)          AS deals_open,
    COALESCE(d.deals_won, 0)           AS deals_won,
    COALESCE(d.deals_lost, 0)          AS deals_lost,
    COALESCE(d.deals_overdue, 0)       AS deals_overdue,
    COALESCE(d.open_pipeline_amount, 0) AS open_pipeline_amount,
    COALESCE(d.won_amount, 0)          AS won_amount,
    COALESCE(d.lost_amount, 0)         AS lost_amount,
    d.next_expected_close,

    COALESCE(n.notes, 0)               AS notes,
    n.last_note_at,

    -- Latest of anything datable on the account. Note the absence of calls and
    -- meetings: this is "last recorded touch", not "last contact".
    GREATEST(
        COALESCE(n.last_note_at,             TIMESTAMP '1970-01-01'),
        COALESCE(d.last_deal_created_at,     TIMESTAMP '1970-01-01'),
        COALESCE(c.last_contact_added_at,    TIMESTAMP '1970-01-01'),
        a.created_time
    ) AS last_recorded_activity_at,

    -- An account with open pipeline and nothing written on it in a quarter is the
    -- report this model exists to produce.
    COALESCE(d.deals_open, 0) > 0
      AND COALESCE(n.last_note_at, a.created_time)
            < TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 90 DAY) AS is_stale_with_open_pipeline
FROM {{ ref('stg_zoho_crm__account') }} a
LEFT JOIN contacts c ON c.zoho_org = a.zoho_org AND c.account_id = a.account_id
LEFT JOIN deals    d ON d.zoho_org = a.zoho_org AND d.account_id = a.account_id
LEFT JOIN notes    n ON n.zoho_org = a.zoho_org AND n.account_id = a.account_id
LEFT JOIN {{ ref('stg_zoho_crm__user') }} u
       ON u.zoho_org = a.zoho_org AND u.user_id = a.owner_id
ORDER BY open_pipeline_amount DESC
