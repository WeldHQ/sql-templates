-- staging.netsuite.deleted_record
-- NetSuite's deletion log. Used to drop transactions that were deleted in
-- NetSuite but are still in the warehouse because an incremental sync never sees
-- a record disappear.
--
-- Grain: record type x record id. Only whole transactions are logged; a line
-- removed from a transaction that still exists is not.
--
-- Syncing this table needs the "Deleted Record Search" permission. Without it,
-- make this model return no rows (add WHERE FALSE) and deleted transactions will
-- stay in the reports.
--
-- Single NetSuite account. To add another, UNION ALL a second block below pointing
-- at that account's connector with a different netsuite_account label.

SELECT
    'account_1'                          AS netsuite_account,
    LOWER(CAST(recordtypeid AS STRING))  AS record_type,
    CAST(recordid AS STRING)             AS record_id,
    CAST(deleteddate AS TIMESTAMP)       AS deleted_at
FROM {{raw.netsuite.deletedrecord}}
