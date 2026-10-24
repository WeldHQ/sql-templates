-- staging.zoho_crm.contact
-- Thin wrapper over raw `contact`. Casts, renames, builds full_name.
--
-- NOTE ON THE ACCOUNT KEY: Zoho's lookup field is called Account_Name, so the
-- connector emits `account_name_id` (the account's id) and `account_name_name`
-- (its label). The _id column is the real foreign key despite the name. It is
-- renamed to account_id here so core reads like a normal star schema.

SELECT
    'org_1'                                 AS zoho_org,
    CAST(id AS STRING)                      AS contact_id,
    CAST(first_name AS STRING)              AS first_name,
    CAST(last_name AS STRING)               AS last_name,
    NULLIF(TRIM(CONCAT(
        COALESCE(CAST(first_name AS STRING), ''), ' ',
        COALESCE(CAST(last_name AS STRING), '')
    )), '')                                 AS full_name,
    LOWER(NULLIF(TRIM(CAST(email AS STRING)), '')) AS email,
    CAST(account_name_id AS STRING)         AS account_id,
    CAST(owner_id AS STRING)                AS owner_id,
    CAST(created_time AS TIMESTAMP)         AS created_time,
    CAST(modified_time AS TIMESTAMP)        AS modified_time
FROM {{raw.zoho_crm.contact}}
