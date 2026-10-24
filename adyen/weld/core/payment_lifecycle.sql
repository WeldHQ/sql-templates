-- core.adyen.payment_lifecycle
-- One row per payment with every step of its life: when it was received,
-- authorised or refused, captured, settled, refunded and charged back, and the
-- amounts Adyen booked at each step. Built from the Payment accounting report.
--
-- Grain: merchant account x PSP reference (one payment).
-- Depends on: staging.adyen.payment_accounting
--
-- Refunds and chargebacks are booked under the original payment's PSP reference
-- (the refund's own reference is in modification_psp_reference), so they roll up
-- onto the payment they reverse.
--
-- AMOUNTS keep Adyen's register signs. net_payable is the sum of the Payable
-- register over all of the payment's records: what this payment contributed to
-- your payouts after refunds, chargebacks and fees, in the settlement currency.
-- Timestamps are wall clock times in the report's time zone.
--
-- The report covers the period your report files cover. A payment received before
-- your first synced file has later steps but no Received or Authorised record.

SELECT
    a.merchant_account,
    a.psp_reference,
    ANY_VALUE(a.company_account)                                                  AS company_account,
    ANY_VALUE(a.merchant_reference)                                               AS merchant_reference,
    ANY_VALUE(a.shopper_reference)                                                AS shopper_reference,
    ANY_VALUE(a.store)                                                            AS store,
    ANY_VALUE(a.payment_method)                                                   AS payment_method,
    ANY_VALUE(a.payment_method_variant)                                           AS payment_method_variant,
    ANY_VALUE(a.payment_currency)                                                 AS payment_currency,
    ANY_VALUE(a.settlement_currency)                                              AS settlement_currency,
    ANY_VALUE(a.time_zone)                                                        AS time_zone,

    MIN(CASE WHEN a.record_category = 'received'        THEN a.booked_at_local END) AS received_at_local,
    MIN(CASE WHEN a.record_category = 'authorised'      THEN a.booked_at_local END) AS authorised_at_local,
    MIN(CASE WHEN a.record_category = 'refused'         THEN a.booked_at_local END) AS refused_at_local,
    MIN(CASE WHEN a.record_category = 'not_captured'    THEN a.booked_at_local END) AS cancelled_or_expired_at_local,
    MIN(CASE WHEN a.record_category = 'sent_for_settle' THEN a.booked_at_local END) AS sent_for_settle_at_local,
    MIN(CASE WHEN a.record_category = 'settled'         THEN a.booked_at_local END) AS settled_at_local,
    MIN(CASE WHEN a.record_category = 'refunded'        THEN a.booked_at_local END) AS first_refunded_at_local,
    MIN(CASE WHEN a.record_category = 'chargeback'      THEN a.booked_at_local END) AS first_chargeback_at_local,

    -- The step the payment is at now: the latest record Adyen booked for it.
    ARRAY_AGG(a.record_type IGNORE NULLS ORDER BY a.booked_at_local DESC LIMIT 1)[SAFE_OFFSET(0)] AS latest_record_type,

    SUM(CASE WHEN a.record_category = 'authorised'      THEN a.authorised_pc ELSE 0 END) AS authorised_amount,
    SUM(CASE WHEN a.record_category = 'sent_for_settle' THEN a.captured_pc   ELSE 0 END) AS captured_amount,
    SUM(CASE WHEN a.record_category = 'settled'         THEN a.payable_sc    ELSE 0 END) AS settled_payable,
    SUM(CASE WHEN a.record_category = 'refunded'        THEN a.payable_sc    ELSE 0 END) AS refunded_payable,
    SUM(CASE WHEN a.record_category = 'chargeback'      THEN a.payable_sc    ELSE 0 END) AS chargeback_payable,
    SUM(COALESCE(a.payable_sc, 0))                                                AS net_payable,
    SUM(a.transaction_fees_sc)                                                    AS transaction_fees,

    -- Adyen's own processing fee can be in a different currency from the
    -- settlement, so it is kept apart with its currency.
    SUM(COALESCE(a.processing_fee_fc, 0))                                         AS processing_fees,
    ANY_VALUE(a.processing_fee_currency)                                          AS processing_fee_currency,

    COUNTIF(a.record_category = 'authorised') > 0                                 AS is_authorised,
    COUNTIF(a.record_category = 'refused') > 0                                    AS is_refused,
    COUNTIF(a.record_category = 'settled') > 0                                    AS is_settled,
    COUNTIF(a.record_category = 'refunded') > 0                                   AS is_refunded,
    COUNTIF(a.record_category = 'chargeback') > 0                                 AS has_chargeback,
    COUNT(*)                                                                      AS record_count
FROM {{staging.adyen.payment_accounting}} a
WHERE a.psp_reference IS NOT NULL
GROUP BY a.merchant_account, a.psp_reference
