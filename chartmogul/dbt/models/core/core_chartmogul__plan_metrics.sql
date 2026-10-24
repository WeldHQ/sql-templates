-- core_chartmogul__plan_metrics
-- ChartMogul's key metrics (MRR, ARR, ARPA, ASP, customers, churn rates, LTV)
-- per plan per day, as ChartMogul computes them.
-- Grain: day x plan. Values are as at the end of the day.
--
-- Amounts are in major units of the ChartMogul account currency. Churn rates are
-- percentages as ChartMogul reports them for each daily interval.
--
-- Roll-ups: mrr and arr add up across plans. customers does not (a customer on
-- two plans appears under both), and neither do arpa, asp, ltv or the churn
-- rates. For an account-wide ARPA, divide summed MRR by a distinct customer count
-- rather than averaging this column.
--
-- Freshness: the stream re-fetches from the day of the previous sync onwards, so
-- older days are not refreshed if ChartMogul later restates them (for example
-- after a billing-system re-import). A full resync brings them back in line.

SELECT
    m.metric_date,
    m.plan_uuid,
    COALESCE(p.plan_name, m.plan_name)               AS plan_name,
    COALESCE(p.plan_external_id, m.plan_external_id) AS plan_external_id,
    p.interval_count,
    p.interval_unit,
    m.mrr,
    m.arr,
    m.customers,
    m.arpa,
    m.asp,
    m.ltv,
    m.customer_churn_rate_pct,
    m.mrr_churn_rate_pct,
    -- Month-end flag: the last synced day of each calendar month, for monthly
    -- reporting without a separate model.
    m.metric_date = MAX(m.metric_date) OVER (
        PARTITION BY m.plan_uuid, DATE_TRUNC(m.metric_date, MONTH)
    )                                                AS is_last_day_of_month
FROM {{ ref('stg_chartmogul__all_metrics') }} m
-- One row per plan_uuid in staging, so no fan-out.
LEFT JOIN {{ ref('stg_chartmogul__plans') }} p USING (plan_uuid)
