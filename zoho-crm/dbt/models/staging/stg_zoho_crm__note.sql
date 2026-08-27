-- stg_zoho_crm__note
-- Thin wrapper over raw `note`. Casts, renames, normalises blanks.
--
-- THE ONE STREAM WITH A REAL PARENT LINK. Every other activity module (call, task,
-- event) loses its What_Id / Who_Id in this connector, but note keeps its parent:
-- Zoho's Parent_Id lookup arrives as `parent_id_id`, and it is the only way to tie
-- anything a rep wrote down back to the deal, account, contact or lead it was
-- about.
--
-- WHAT MODULE IS THE PARENT? Zoho's API exposes $se_module to say which one, and
-- the connector does not sync it. Record ids are globally unique across Zoho
-- modules though, so the module can be recovered by joining parent_id to each
-- module in turn and seeing which one matches - that is what
-- core_zoho_crm__account_360 does. `parent_name` is the label Zoho denormalised
-- onto the note and is kept only as a fallback for a parent that no longer exists.

SELECT
    'org_1'                                 AS zoho_org,
    CAST(id AS STRING)                      AS note_id,
    NULLIF(TRIM(CAST(note_title AS STRING)), '')   AS note_title,
    NULLIF(TRIM(CAST(note_content AS STRING)), '') AS note_content,
    CAST(parent_id_id AS STRING)            AS parent_id,
    NULLIF(TRIM(CAST(parent_id_name AS STRING)), '') AS parent_name,
    CAST(owner_id AS STRING)                AS owner_id,
    CAST(created_time AS TIMESTAMP)         AS created_time,
    CAST(modified_time AS TIMESTAMP)        AS modified_time
FROM {{ source('zoho_crm', 'note') }}
