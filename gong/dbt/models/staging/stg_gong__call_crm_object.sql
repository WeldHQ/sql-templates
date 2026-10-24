-- stg_gong__call_crm_object
-- The CRM records a call is linked to, from raw `call_context_integration`. One row
-- per call x CRM object.
--
-- The raw table is one row per CRM FIELD of every linked object, and it holds the
-- context both as it is now and as it was at the time of the call (`timing`), so the same object appears many times. Only the link itself is
-- kept here: system, object type and object id. The field values are not unpacked,
-- because their shape varies by CRM and field.
--
-- object_type is the CRM's own label ('Account', 'Opportunity', 'Contact', 'Lead'
-- for Salesforce; HubSpot reports deals and companies under its own names).
--
-- Single Gong instance; see staging.gong.call.

SELECT DISTINCT
    'account_1'                                AS gong_account,
    CAST(call_id AS STRING)                    AS call_id,
    NULLIF(CAST(systems AS STRING), '')        AS crm_system,
    NULLIF(CAST(object_type AS STRING), '')    AS object_type,
    CAST(object_id AS STRING)                  AS object_id
FROM {{ source('gong', 'call_context_integration') }}
WHERE call_id IS NOT NULL
  AND object_id IS NOT NULL
