-- stg_walmart__seller
-- One row per Walmart seller account, carrying the timezone the order-based
-- reports localise to. There is no raw source: the connector does not sync the
-- account's settings, so this is set by hand.
--
-- SET report_timezone. Walmart sends order timestamps in UTC. Left at 'UTC',
-- late-evening orders land on the next day compared with how your team reads
-- Seller Center. Settlement dates in the recon report are calendar dates already
-- and are not converted.
--
-- To add an account, add a row here with the label you use in the other staging
-- models.

SELECT
    'seller_1' AS walmart_seller,
    'UTC'      AS report_timezone
