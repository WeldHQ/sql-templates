-- core_toast_analytics__labor_by_job
-- Labor hours and cost per job per day, with each job's cost as a share of the
-- restaurant's net sales that day (Toast's labor cost percentage, by job).
-- Grain: business date x restaurant x job.
--
-- Net sales come from Toast's daily labor report for the same restaurant and day,
-- the figure Toast itself divides by. job_cost_pct_of_net_sales on each row sums
-- across jobs to the restaurant's labor percentage for the day; over a longer
-- period, sum total_cost and divide by the period's net sales instead.

SELECT
    j.business_date,
    j.restaurant_id,
    j.restaurant_name,
    j.job_id,
    j.job_title,
    j.job_code,
    j.regular_hours,
    j.overtime_hours,
    j.total_hours,
    j.regular_cost,
    j.overtime_cost,
    j.total_cost,
    l.net_sales                                    AS restaurant_net_sales,
    SAFE_DIVIDE(j.total_cost, l.net_sales)         AS job_cost_pct_of_net_sales
FROM {{ ref('stg_toast_analytics__labor_by_job') }} j
LEFT JOIN {{ ref('stg_toast_analytics__labor') }} l USING (restaurant_id, business_date)
