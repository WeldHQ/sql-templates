-- staging.bigcommerce.store
-- Static settings per store. No raw source: the connector does not sync the store
-- profile, so the reporting time zone has to be declared here.
--
-- WHY THIS EXISTS. BigCommerce stores every order and refund timestamp in UTC, while
-- the control panel reports days in the store's own time zone (Settings → General →
-- Date & timezone). Truncate UTC to a date and every late-evening order in the
-- Americas, or every early-morning order in Asia, lands on the wrong day. Set
-- report_timezone to the IANA name your store uses and every core model follows.
--
-- Multi-store: add one row per store, with the same label the other staging models
-- use for it.

SELECT * FROM UNNEST([
    STRUCT('store_1' AS bigcommerce_store, 'UTC' AS report_timezone)
])
