-- staging.netsuite.entity
-- Customers, vendors, employees, partners and projects in one table, used to name
-- the counterparty on aging rows.
--
-- Grain: one row per entity.
--
-- Single NetSuite account. To add another, UNION ALL a second block below pointing
-- at that account's connector with a different netsuite_account label.

SELECT
    'account_1'                                                     AS netsuite_account,
    CAST(id AS STRING)                                              AS entity_id,
    CAST(type AS STRING)                                            AS entity_type,
    COALESCE(NULLIF(TRIM(CAST(altname AS STRING)), ''), CAST(entityid AS STRING)) AS entity_name
FROM {{raw.netsuite.entity}}
