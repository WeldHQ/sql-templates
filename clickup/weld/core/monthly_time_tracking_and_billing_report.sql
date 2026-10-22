-- core.clickup.monthly_time_tracking_and_billing_report
-- Monthly Time Tracking and Billing Report. Generates a monthly time tracking and
-- billing report using data from ClickUp. It calculates the billable and non-
-- billable time for each user, as well as the total time spent. The report also
-- includes the billable amount, calculated based on a hypothetical rate of $50 per
-- hour.
--
-- From the weld.app template library. Not reconciled against ClickUp;
-- check the output against the source before relying on it.

with
    MonthlyTimeSummary as (
        select
            date_trunc(timestamp_millis(cast(start as int)), month) as month
          , user_id
          , user_username
          , sum(
                case
                    when billable then duration
                    else 0
                end
            ) as billable_time
          , sum(
                case
                    when not billable then duration
                    else 0
                end
            ) as non_billable_time
          , sum(duration) as total_time
        from
            {{raw.clickup.time}}
        group by
            month
          , user_id
          , user_username
    )
select
    month
  , user_id
  , user_username
  , billable_time
  , non_billable_time
  , total_time
  , billable_time * 50 as billable_amount -- Hypothetical rate of $50 per hour, adjust as needed
from
    MonthlyTimeSummary
order by
    month desc
  , user_id
