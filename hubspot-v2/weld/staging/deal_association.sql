-- staging.hubspot_v2.deal_association
-- Thin wrapper over raw `deal_association`: every association from a deal to a
-- company, contact or other record. Grain: deal x associated record x association type.
--
-- A deal can be associated with several companies, and each association can carry
-- several types (an unlabeled default plus "Primary" plus any custom labels), so this
-- table has more than one row per deal-company pair. Picking one company per deal is
-- business logic and happens in core.hubspot_v2.deal_pipeline.

SELECT DISTINCT
    'portal_1'                         AS hubspot_portal,
    CAST(from_id AS STRING)            AS deal_id,
    CAST(to_id AS STRING)              AS to_id,
    -- Singular object name: 'company', 'contact', 'deal', 'line_item', 'ticket', ...
    LOWER(CAST(to_object_type AS STRING)) AS to_object_type,
    CAST(type_id AS STRING)            AS association_type_id,
    CAST(category AS STRING)           AS association_category,
    NULLIF(TRIM(label), '')            AS association_label
FROM {{raw.hubspot_v2.deal_association}}
