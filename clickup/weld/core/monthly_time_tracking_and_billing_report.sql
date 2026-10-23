-- core.clickup.monthly_time_tracking_and_billing_report
-- Monthly Time Tracking and Billing Report. Generates a monthly time tracking and
-- billing report using data from ClickUp. It calculates the billable and non-
-- billable time for each user, as well as the total time spent. The report also
-- includes the billable amount, calculated based on a hypothetical rate of $50 per
-- hour.
--
-- Grain: month x user, by the time entry's start (UTC). ClickUp records
-- durations in milliseconds: the *_time columns stay in milliseconds as
-- ClickUp reports them, the *_hours columns convert them. Running timers carry
-- a negative duration and are left out until they stop.
--
-- From the weld.app template library, corrected. Not reconciled against
-- ClickUp; check the output against the source before relying on it.

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
        where
            duration >= 0
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
  , billable_time / 3600000 as billable_hours
  , non_billable_time / 3600000 as non_billable_hours
  , total_time / 3600000 as total_hours
  , billable_time / 3600000 * 50 as billable_amount -- hypothetical rate of $50 per hour, adjust as needed
from
    MonthlyTimeSummary
order by
    month desc
  , user_id
