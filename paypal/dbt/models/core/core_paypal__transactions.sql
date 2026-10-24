-- core_paypal__transactions
-- Every PayPal transaction record, classified: the itemised activity behind
-- PayPal's activity download and balance report.
-- Grain: transaction id x event code.
--
-- Classification uses the first three characters of PayPal's transaction event
-- code (T00 payments, T01 fees, T02 currency conversions, T03 bank deposits, T04
-- bank withdrawals, T11 reversals, T12 adjustments, T13 authorizations, T15 and T21
-- holds and releases, T98 informational). T1107 is split out as a refund.
--
-- is_balance_affecting is TRUE for completed (S) or later-reversed (V) records
-- outside the authorization (T13) and informational (T98) groups. Pending (P) and
-- denied (D) records are kept but do not count. The reversal of a V record is its
-- own T11 record, so counting both is what makes the balance net to zero.
--
-- Amounts are in the transaction currency, major units, signed from your account's
-- point of view: in is positive, out is negative. net_amount = gross_amount +
-- fee_amount. Dates are UTC.

SELECT
    transaction_id,
    event_code,
    DATE(initiated_at)                          AS transaction_date,
    initiated_at,
    updated_at,
    status,
    SUBSTR(event_code, 1, 3)                    AS event_group,
    CASE
        WHEN event_code = 'T1107'                  THEN 'refund'
        WHEN STARTS_WITH(event_code, 'T00')        THEN IF(gross_amount < 0, 'payment_sent', 'payment_received')
        WHEN STARTS_WITH(event_code, 'T01')        THEN 'fee'
        WHEN STARTS_WITH(event_code, 'T02')        THEN 'currency_conversion'
        WHEN STARTS_WITH(event_code, 'T03')        THEN 'bank_deposit'
        WHEN STARTS_WITH(event_code, 'T04')        THEN 'bank_withdrawal'
        WHEN STARTS_WITH(event_code, 'T11')
          OR STARTS_WITH(event_code, 'T12')        THEN 'chargeback_or_reversal'
        WHEN STARTS_WITH(event_code, 'T13')        THEN 'authorization'
        WHEN STARTS_WITH(event_code, 'T15')
          OR STARTS_WITH(event_code, 'T21')        THEN 'hold_or_release'
        WHEN STARTS_WITH(event_code, 'T98')        THEN 'informational'
        ELSE 'other'
    END                                         AS category,
    status IN ('S', 'V')
      AND NOT STARTS_WITH(event_code, 'T13')
      AND NOT STARTS_WITH(event_code, 'T98')    AS is_balance_affecting,
    currency,
    gross_amount,
    fee_amount,
    COALESCE(gross_amount, 0) + fee_amount      AS net_amount,
    sales_tax_amount,
    shipping_amount,
    invoice_id,
    custom_field,
    reference_transaction_id,
    reference_id_type,
    subject,
    payment_method_type,
    instrument_type,
    payer_account_id,
    payer_email,
    payer_name,
    payer_country,
    paypal_account_number
FROM {{ ref('stg_paypal__transaction') }}
