-- staging.adobe_commerce.store_timezone
-- The time zone your Adobe Commerce reports use. No raw source: EDIT THIS FILE.
--
-- Adobe Commerce stores order times in UTC and its admin reports convert them to
-- the store's configured time zone (Stores > Configuration > General > Locale
-- Options > Timezone). That setting lives in core_config_data, which is not among
-- the synced tables, so it has to be stated here. Left at UTC, every order placed
-- in the evening of a store west of Greenwich, or the early morning of one east of
-- it, lands on the wrong day.
--
-- Use an IANA name such as 'Europe/Copenhagen' or 'America/New_York'. One row per
-- connected store (adobe_commerce_store label); to give individual store views
-- their own zone, add a store_id column here and to the join in core.

SELECT
    'store_1' AS adobe_commerce_store,
    'UTC'     AS report_timezone
