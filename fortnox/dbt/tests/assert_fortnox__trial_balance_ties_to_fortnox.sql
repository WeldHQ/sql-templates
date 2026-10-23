-- Opening balance plus the year's postings must equal Fortnox's own closing balance for
-- every account and financial year.
--
-- `closing_balance_fortnox` is computed by Fortnox independently of the voucher rows, so
-- this checks the whole chain: that every voucher row synced, that removed rows are
-- excluded, and that rows land on the right financial year.
--
-- The accounts stream is incremental on the account's own modification date, and new
-- postings may not count as a modification. If only the current, open financial year
-- fails, re-sync the accounts stream before suspecting the ledger.

SELECT
    financial_year_id,
    account_number,
    closing_balance,
    closing_balance_fortnox,
    closing_balance_difference
FROM {{ ref('core_fortnox__trial_balance') }}
WHERE closing_balance_fortnox IS NOT NULL
  AND ABS(closing_balance_difference) > 0.01
