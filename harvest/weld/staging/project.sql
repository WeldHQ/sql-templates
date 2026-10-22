-- staging.harvest.project
-- Thin wrapper over raw `project`. One row per project, latest version.
-- `fee` (fixed-fee amount) and `cost_budget` arrive as text and are cast here.

SELECT
    CAST(id AS STRING)                              AS project_id,
    CAST(name AS STRING)                            AS project_name,
    CAST(code AS STRING)                            AS project_code,
    CAST(client_id AS STRING)                       AS client_id,
    CAST(client_name AS STRING)                     AS client_name,
    UPPER(CAST(client_currency AS STRING))          AS client_currency,
    COALESCE(is_active, FALSE)                      AS is_active,
    COALESCE(is_billable, FALSE)                    AS is_billable,
    COALESCE(is_fixed_fee, FALSE)                   AS is_fixed_fee,
    LOWER(CAST(bill_by AS STRING))                  AS bill_by,
    LOWER(CAST(budget_by AS STRING))                AS budget_by,
    CAST(budget AS FLOAT64)                         AS budget,
    COALESCE(budget_is_monthly, FALSE)              AS budget_is_monthly,
    SAFE_CAST(CAST(cost_budget AS STRING) AS FLOAT64) AS cost_budget,
    COALESCE(cost_budget_include_expenses, FALSE)   AS cost_budget_include_expenses,
    SAFE_CAST(CAST(fee AS STRING) AS FLOAT64)       AS fee,
    SAFE_CAST(CAST(starts_on AS STRING) AS DATE)    AS starts_on,
    SAFE_CAST(CAST(ends_on AS STRING) AS DATE)      AS ends_on
FROM {{raw.harvest.project}}
WHERE id IS NOT NULL
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY CAST(id AS STRING)
    ORDER BY CAST(updated_at AS TIMESTAMP) DESC, _weld_synced DESC
) = 1
