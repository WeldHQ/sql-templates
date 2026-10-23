-- core_youtube_analytics__viewer_demographics_daily
-- Who watches each channel: views split by age group and gender per day, the
-- "Age" and "Gender" cards of the YouTube Studio Audience tab.
--
-- Grain: date_day x channel_id x age_group x gender. Dates are Pacific Time.
-- Depends on: staging.youtube_analytics.channel_demographics, .channel_basic
--
-- YouTube delivers demographics as percentages per slice (video, country,
-- subscribed status, live or on demand), not as counts. Adding those
-- percentages up across slices gives a number with no meaning: a slice with
-- 3 views would count as much as one with 30,000. Here each percentage is
-- multiplied by the views of its own slice from the activity report, which
-- turns it into estimated views; those can be summed and divided again.
--
-- estimated_views only covers signed-in viewers whose age and gender YouTube
-- knows, and slices that YouTube withheld from either report for privacy drop
-- out. Compare shares, not totals, with Studio, and re-derive the share from
-- summed estimated_views for a longer period.

WITH slice_views AS (
    -- The activity report is already one row per slice; the SUM only guards
    -- against a slice that arrives twice.
    SELECT
        date_day,
        channel_id,
        video_id,
        live_or_on_demand,
        subscribed_status,
        country_code,
        SUM(views) AS views
    FROM {{ ref('stg_youtube_analytics__channel_basic') }}
    GROUP BY 1, 2, 3, 4, 5, 6
),

weighted AS (
    SELECT
        d.date_day,
        d.channel_id,
        d.age_group,
        d.gender,
        d.share_of_slice_views * s.views AS estimated_views
    FROM {{ ref('stg_youtube_analytics__channel_demographics') }} d
    -- slice_views is one row per slice, so each demographic row matches at most
    -- one slice. IS NOT DISTINCT FROM keeps slices whose video or country is
    -- empty.
    JOIN slice_views s
      ON  s.date_day = d.date_day
      AND s.channel_id = d.channel_id
      AND s.video_id IS NOT DISTINCT FROM d.video_id
      AND s.live_or_on_demand IS NOT DISTINCT FROM d.live_or_on_demand
      AND s.subscribed_status IS NOT DISTINCT FROM d.subscribed_status
      AND s.country_code IS NOT DISTINCT FROM d.country_code
)

SELECT
    date_day,
    channel_id,
    age_group,
    gender,
    SUM(estimated_views) AS estimated_views,
    SAFE_DIVIDE(
        SUM(estimated_views),
        SUM(SUM(estimated_views)) OVER (PARTITION BY date_day, channel_id)
    ) AS share_of_views
FROM weighted
GROUP BY 1, 2, 3, 4
