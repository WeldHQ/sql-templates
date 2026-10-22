-- staging.woocommerce.store_settings
-- One row per store with the settings the reports need, read from wp_options so
-- nothing has to be hardcoded:
--
--   currency          woocommerce_currency, the store's CURRENT currency
--   analytics_date_type
--                     woocommerce_date_type: which order date WooCommerce Analytics
--                     reports by (date_created, date_paid or date_completed).
--                     NULL when never saved; WooCommerce then uses date_paid.
--   excluded_statuses woocommerce_excluded_report_order_statuses, the statuses
--                     Analytics leaves out of its totals. Stored as a PHP-serialized
--                     array, so the strings are pulled out with a regex and given
--                     the 'wc-' prefix used in wc_order_stats.status. NULL when
--                     never saved; WooCommerce then excludes pending, failed and
--                     cancelled.
--
-- An aggregate with no GROUP BY always returns exactly one row, even when an option
-- is missing.

WITH options AS (
    SELECT
        MAX(IF(option_name = 'woocommerce_currency', option_value, NULL))  AS currency,
        MAX(IF(option_name = 'woocommerce_date_type', option_value, NULL)) AS analytics_date_type,
        MAX(IF(option_name = 'woocommerce_excluded_report_order_statuses', option_value, NULL))
            AS excluded_statuses_serialized
    FROM {{raw.woocommerce.wp_options}}
    WHERE option_name IN (
        'woocommerce_currency',
        'woocommerce_date_type',
        'woocommerce_excluded_report_order_statuses'
    )
)

SELECT
    'store_1'                                AS woocommerce_store,
    NULLIF(TRIM(currency), '')               AS currency,
    NULLIF(TRIM(analytics_date_type), '')    AS analytics_date_type,
    -- NULL (not an empty array) when the option was never saved, so core can tell
    -- "never set" from "set to exclude nothing".
    CASE
        -- Each array element is serialized as s:<length>:"<status>"; prefix every
        -- status with 'wc-' and pull them out.
        WHEN excluded_statuses_serialized IS NOT NULL THEN REGEXP_EXTRACT_ALL(
            REGEXP_REPLACE(excluded_statuses_serialized, r's:\d+:"([^"]*)"', r's:0:"wc-\1"'),
            r's:\d+:"([^"]*)"'
        )
    END AS excluded_statuses
FROM options
