-- staging.toast.service_charge
-- Thin wrapper over raw `order_check_applied_service_charge`. One row per service
-- charge applied to a check. Gratuities (auto-gratuity) are flagged; Toast reports
-- them apart from other service charges.

SELECT
    CAST(guid AS STRING)                AS applied_service_charge_id,
    CAST(order_check_guid AS STRING)    AS check_id,
    CAST(order_guid AS STRING)          AS order_id,
    CAST(name AS STRING)                AS service_charge_name,
    CAST(charge_amount AS FLOAT64)      AS charge_amount,
    COALESCE(gratuity, FALSE)           AS is_gratuity,
    COALESCE(CAST(refund_details_refund_amount AS FLOAT64), 0) AS refund_amount
FROM {{raw.toast.order_check_applied_service_charge}}
WHERE guid IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY CAST(guid AS STRING) ORDER BY _weld_synced DESC) = 1
