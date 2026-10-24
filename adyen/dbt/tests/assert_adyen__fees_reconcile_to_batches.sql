-- Transaction fees by payment method must sum to the same total as the batch view.
--
-- Both models read the same settlement entries with different groupings. If the
-- totals differ, one of them is filtering entries the other keeps, and fee rates
-- per payment method would not add up to what Adyen withheld.

WITH by_method AS (
    SELECT merchant_account, net_currency, SUM(transaction_fees) AS fees
    FROM {{ ref('core_adyen__fees_by_payment_method') }}
    GROUP BY 1, 2
),

by_batch AS (
    SELECT merchant_account, net_currency, SUM(transaction_fees) AS fees
    FROM {{ ref('core_adyen__settlement_batches') }}
    GROUP BY 1, 2
)

SELECT
    COALESCE(m.merchant_account, b.merchant_account) AS merchant_account,
    COALESCE(m.net_currency, b.net_currency)         AS net_currency,
    m.fees                                           AS fees_by_method,
    b.fees                                           AS fees_by_batch
FROM by_method m
FULL OUTER JOIN by_batch b
  ON m.merchant_account = b.merchant_account
 AND m.net_currency = b.net_currency
WHERE ABS(COALESCE(m.fees, 0) - COALESCE(b.fees, 0)) > 0.01
