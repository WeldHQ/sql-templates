-- Every paid-out batch: its entries must add up to the payout Adyen sent.
--
-- The MerchantPayout entry is Adyen's own figure for what reached your bank, so this
-- checks the model against an independent number. If it holds, no entry was dropped
-- or mis-signed on the way.
--
-- A failure usually means one of three things:
--
--   1. A settlement detail report file was not delivered or not synced, so the batch
--      is missing entries. Check the report list in the Customer Area.
--   2. The same report is generated at company and merchant account level with
--      different column settings, so entries are counted twice.
--   3. A journal type changed sign convention. Check the Balancetransfer and
--      DepositCorrection entries in the failing batch first.
--
-- One cent of tolerance per batch.

SELECT
    merchant_account,
    batch_number,
    net_currency,
    net_movement,
    payout,
    unreconciled_amount
FROM {{ ref('core_adyen__settlement_batches') }}
WHERE has_payout
  AND ABS(unreconciled_amount) > 0.01
