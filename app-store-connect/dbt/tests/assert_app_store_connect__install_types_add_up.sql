-- The install type columns in downloads_and_deletions add up to total_installs.
-- other_installs exists to catch any download type Apple sends beyond the four it
-- documents; if this fails, a bucket is double counting or one was dropped.

SELECT *
FROM {{ ref('core_app_store_connect__downloads_and_deletions') }}
WHERE first_time_downloads + redownloads + manual_updates + restores + other_installs
      != total_installs
