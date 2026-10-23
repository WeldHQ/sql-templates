-- One row per transaction id and event code.

SELECT transaction_id, event_code, COUNT(*) AS rows_at_grain
FROM {{ ref('core_paypal__transactions') }}
GROUP BY 1, 2
HAVING COUNT(*) > 1
