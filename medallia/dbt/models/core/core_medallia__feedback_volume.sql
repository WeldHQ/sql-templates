-- core_medallia__feedback_volume
-- Feedback records created and responses received per unit per day, with response
-- rate.
-- Grain: day x medallia_account x unit. Dates are UTC days.
-- Depends on: staging.medallia.feedback, .unit
--
-- TWO DATES, ON PURPOSE. A record is created when the invitation goes out
-- (`created_at`) and answered later (`responded_at`). The model counts each on its
-- own date:
--   records_created     records whose created_at falls on the day;
--   responses           records whose responded_at falls on the day;
--   created_and_responded  of the records created that day, how many have been
--                       answered by now.
-- `response_rate` is created_and_responded / records_created, a cohort rate: it is
-- the rate for invitations sent that day, and it keeps rising for recent days as
-- late answers arrive. Do not divide responses by records_created; the two count
-- different records.
--
-- Records with no creation date (web intercepts and other unsolicited feedback, on
-- most instances) count as responses but never in the cohort columns.
--
-- Built on a day spine so a quiet day returns zeros instead of disappearing.

WITH feedback AS (
    SELECT
        medallia_account,
        feedback_id,
        unit_identifier,
        DATE(created_at)   AS created_date,
        DATE(responded_at) AS responded_date
    FROM {{ ref('stg_medallia__feedback') }}
),

day_spine AS (
    SELECT day
    FROM UNNEST(GENERATE_DATE_ARRAY(
        -- Earliest of either date. LEAST() would return NULL if one side has none.
        (SELECT MIN(d) FROM feedback, UNNEST([created_date, responded_date]) AS d),
        CURRENT_DATE(),
        INTERVAL 1 DAY
    )) AS day
),

units AS (
    SELECT DISTINCT
        f.medallia_account,
        f.unit_identifier,
        u.unit_name
    FROM feedback f
    LEFT JOIN {{ ref('stg_medallia__unit') }} u
           ON u.medallia_account = f.medallia_account
          AND u.unit_identifier  = f.unit_identifier
),

created AS (
    SELECT
        created_date AS day,
        medallia_account,
        unit_identifier,
        COUNT(*)                         AS records_created,
        COUNTIF(responded_date IS NOT NULL) AS created_and_responded
    FROM feedback
    WHERE created_date IS NOT NULL
    GROUP BY 1, 2, 3
),

responded AS (
    SELECT
        responded_date AS day,
        medallia_account,
        unit_identifier,
        COUNT(*) AS responses
    FROM feedback
    WHERE responded_date IS NOT NULL
    GROUP BY 1, 2, 3
)

SELECT
    s.day,
    u.medallia_account,
    u.unit_identifier,
    u.unit_name,
    COALESCE(c.records_created, 0)       AS records_created,
    COALESCE(r.responses, 0)             AS responses,
    COALESCE(c.created_and_responded, 0) AS created_and_responded,
    SAFE_DIVIDE(c.created_and_responded, c.records_created) AS response_rate
FROM day_spine s
CROSS JOIN units u
LEFT JOIN created c
       ON c.day              = s.day
      AND c.medallia_account = u.medallia_account
      -- Null-safe: records with no unit form their own group, and a plain
      -- equality would drop them from the series.
      AND COALESCE(c.unit_identifier, '') = COALESCE(u.unit_identifier, '')
LEFT JOIN responded r
       ON r.day              = s.day
      AND r.medallia_account = u.medallia_account
      AND COALESCE(r.unit_identifier, '') = COALESCE(u.unit_identifier, '')
