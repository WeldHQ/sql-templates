-- staging.salesforce.account
-- Thin wrapper over raw `account`. Casts, renames, drops deleted records.
-- Grain: one row per account.
--
-- Salesforce's Billing Address is a compound field, which the connector skips;
-- its parts (billing_country, billing_city, ...) arrive as their own columns.

SELECT
    'org_1'                                        AS salesforce_org,
    CAST(id AS STRING)                             AS account_id,
    NULLIF(TRIM(CAST(name AS STRING)), '')         AS account_name,
    NULLIF(TRIM(CAST(type AS STRING)), '')         AS account_type,
    NULLIF(TRIM(CAST(industry AS STRING)), '')     AS industry,
    NULLIF(TRIM(CAST(billing_country AS STRING)), '') AS billing_country,
    CAST(owner_id AS STRING)                       AS owner_id,
    CAST(parent_id AS STRING)                      AS parent_account_id,
    CAST(created_date AS TIMESTAMP)                AS created_at
FROM {{raw.salesforce.account}}
WHERE NOT COALESCE(is_deleted, FALSE)
