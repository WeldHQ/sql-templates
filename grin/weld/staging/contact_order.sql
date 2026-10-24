-- staging.grin.contact_order
-- Thin wrapper over raw `contact_order`: one row per product seeding order Grin
-- placed in your store for a creator, with the campaign and product selection it
-- fulfils.
--
-- Single Grin account; see staging.grin.campaign.

SELECT
    'account_1'                                  AS grin_account,
    CAST(id AS STRING)                           AS order_id,
    CAST(campaign_id AS STRING)                  AS campaign_id,
    CAST(contact_id AS STRING)                   AS contact_id,
    CAST(product_selection_id AS STRING)         AS product_selection_id,
    CAST(external_order_id AS STRING)            AS external_order_id,
    NULLIF(CAST(shipment_status AS STRING), '')  AS shipment_status,
    CAST(created_at AS TIMESTAMP)                AS created_at
FROM {{raw.grin.contact_order}}
WHERE id IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY id ORDER BY updated_at DESC, _weld_synced DESC) = 1
