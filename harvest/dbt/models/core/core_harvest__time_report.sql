-- core_harvest__time_report
-- Harvest's Time report: hours, billable hours, billable amount and cost.
-- Grain: day x user x project x task.
--
-- Money follows Harvest's own conventions:
--   billable_amount = rounded_hours x billable_rate, for billable entries only,
--                     in the CLIENT's currency (client_currency)
--   cost_amount     = hours x cost_rate, in the ACCOUNT's currency
--                     (account_currency), because cost rates are set per person
--                     in the account currency
-- Do not add the two across clients with different currencies.
--
-- Running timers are included with the hours tracked so far.

SELECT
    t.spent_date,
    t.user_id,
    ANY_VALUE(t.user_name)                                          AS user_name,
    ANY_VALUE(t.client_id)                                          AS client_id,
    ANY_VALUE(t.client_name)                                        AS client_name,
    t.project_id,
    ANY_VALUE(t.project_name)                                       AS project_name,
    ANY_VALUE(t.project_code)                                       AS project_code,
    t.task_id,
    ANY_VALUE(t.task_name)                                          AS task_name,
    ANY_VALUE(t.client_currency)                                    AS client_currency,
    ANY_VALUE(c.currency)                                           AS account_currency,
    COUNT(*)                                                        AS time_entries,
    ROUND(SUM(t.hours), 4)                                          AS hours,
    ROUND(SUM(t.rounded_hours), 4)                                  AS rounded_hours,
    ROUND(SUM(IF(t.is_billable, t.rounded_hours, 0)), 4)            AS billable_hours,
    ROUND(SUM(IF(t.is_billable, 0, t.rounded_hours)), 4)            AS non_billable_hours,
    ROUND(SUM(IF(t.is_billable, t.rounded_hours * COALESCE(t.billable_rate, 0), 0)), 2) AS billable_amount,
    ROUND(SUM(IF(t.is_billable AND NOT t.is_billed, t.rounded_hours * COALESCE(t.billable_rate, 0), 0)), 2) AS uninvoiced_amount,
    ROUND(SUM(t.hours * COALESCE(t.cost_rate, 0)), 2)               AS cost_amount,
    COUNTIF(t.cost_rate IS NULL)                                    AS entries_without_cost_rate
FROM {{ ref('stg_harvest__time_entry') }} t
CROSS JOIN {{ ref('stg_harvest__company') }} c
GROUP BY t.spent_date, t.user_id, t.project_id, t.task_id
