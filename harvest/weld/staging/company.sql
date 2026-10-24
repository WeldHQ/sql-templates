-- staging.harvest.company
-- Thin wrapper over raw `company`. One row: the Harvest account's settings.
-- Used for the first day of the week and the account currency.

SELECT
    CAST(name AS STRING)                    AS company_name,
    CAST(week_start_day AS STRING)          AS week_start_day,
    UPPER(CAST(currency AS STRING))         AS currency,
    CAST(weekly_capacity AS FLOAT64) / 3600 AS default_weekly_capacity_hours
FROM {{raw.harvest.company}}
QUALIFY ROW_NUMBER() OVER (ORDER BY _weld_synced DESC) = 1
