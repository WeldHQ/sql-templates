-- core_paypal__balance_reconciliation
-- Ties the transaction history to the balance PayPal reports today.
-- Grain: PayPal account x currency.
--
-- PayPal's transaction API only goes back three years, so the synced history
-- starts part-way through the account's life. implied_opening_balance is the
-- balance the account must have held just before the first synced transaction for
-- today's balance to be right:
--   implied_opening_balance = total_balance - sum of all balance-affecting net_amount
-- Use it as the opening figure when building a running balance from
-- daily_balance_activity. A negative or implausible value means records are
-- missing or misclassified.
--
-- Amounts in major units of each currency. The balance snapshot is as of the last
-- sync; transactions can lag PayPal by up to a few hours.

WITH activity AS (
    SELECT
        currency,
        MIN(transaction_date)    AS first_transaction_date,
        MAX(transaction_date)    AS last_transaction_date,
        SUM(net_amount)          AS net_change_since_first_transaction
    FROM {{ ref('core_paypal__transactions') }}
    WHERE is_balance_affecting
    GROUP BY currency
)

SELECT
    b.paypal_account_id,
    COALESCE(b.currency, a.currency)                  AS currency,
    b.is_primary_currency,
    b.as_of_at                                        AS balance_as_of,
    b.total_balance,
    b.available_balance,
    b.withheld_balance,
    a.first_transaction_date,
    a.last_transaction_date,
    a.net_change_since_first_transaction,
    b.total_balance - COALESCE(a.net_change_since_first_transaction, 0) AS implied_opening_balance
FROM {{ ref('stg_paypal__balance') }} b
-- Both sides are one row per currency (one PayPal account per connector).
FULL OUTER JOIN activity a ON a.currency = b.currency
