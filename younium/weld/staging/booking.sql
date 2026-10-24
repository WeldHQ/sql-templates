-- staging.younium.booking
-- Younium bookings: one row per booking, the record Younium writes when an order
-- (subscription) is created, changed or cancelled. Each booking carries the change
-- in committed MRR (CMRR), ACV and TCV that the event caused, and Younium's own
-- classification of it (NewCustomer, Expansion, Contraction, CustomerChurn,
-- Reactivate, NoChange, SplitOrder).
-- Grain: one row per booking id.
--
-- Units: Younium amounts are decimals in major units, not cents. Each amount comes
-- twice: in the order's currency (`currency`) and converted to the Younium base
-- currency. Both are kept.
--
-- The QUALIFY keeps one row per id in case a booking arrives twice.

SELECT
    CAST(id AS STRING)                                          AS booking_id,
    CAST(order_id AS STRING)                                    AS order_id,
    CAST(order_order_number AS STRING)                          AS order_number,
    CAST(effective_date AS TIMESTAMP)                           AS effective_at,
    CAST(created AS TIMESTAMP)                                  AS created_at,
    CAST(modified AS TIMESTAMP)                                 AS modified_at,
    CAST(booking_type AS STRING)                                AS booking_type,
    CAST(change_type AS STRING)                                 AS change_type,
    CAST(account_category AS STRING)                            AS account_category,
    CAST(classification_name AS STRING)                         AS classification_name,
    CAST(classification_classification_type AS STRING)          AS classification_type,
    UPPER(NULLIF(TRIM(CAST(currency AS STRING)), ''))           AS order_currency,
    CAST(cmrr_amount AS NUMERIC)                                AS cmrr_change,
    CAST(cmrr_amount_in_base_currency AS NUMERIC)               AS cmrr_change_base,
    CAST(acv_amount AS NUMERIC)                                 AS acv_change,
    CAST(acv_amount_in_base_currency AS NUMERIC)                AS acv_change_base,
    CAST(tcv_amount AS NUMERIC)                                 AS tcv_change,
    CAST(tcv_amount_in_base_currency AS NUMERIC)                AS tcv_change_base,
    CAST(one_time_fees_amount_in_base_currency AS NUMERIC)      AS one_time_fees_base
FROM {{raw.younium.booking}}
WHERE id IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY id ORDER BY modified DESC, _weld_synced DESC) = 1
