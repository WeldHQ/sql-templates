-- core_salesforce__lead_funnel_daily
-- Leads created and converted per day per lead source, with the conversion of
-- each day's new leads followed through to a won opportunity.
-- Grain: date_day x salesforce_org x lead_source.
-- Depends on: staging.salesforce.lead, core.salesforce.opportunity_pipeline
--
-- TWO VIEWS OF CONVERSION, both on this row:
--   leads_converted   -> leads whose converted_date is this day, whenever they
--                        were created. Activity view: "how many did we convert
--                        today".
--   cohort_*          -> of the leads CREATED this day, how many have converted
--                        so far, how long it took, and how many became a won
--                        opportunity. Cohort view: "how good were these leads".
--                        Recent cohorts keep rising as their leads convert.
--
-- ROLLING UP. Sum the parts and divide once: conversion_rate is
-- cohort_converted / leads_created, average_days_to_convert is
-- cohort_days_to_convert / cohort_converted.
--
-- lead_source NULL is reported as '(none)', so it stays visible in a chart and
-- joins on the spine. Lead conversion into an existing opportunity is possible,
-- so two leads can point at the same opportunity; each lead is still counted once.

WITH leads AS (
    SELECT
        l.salesforce_org,
        COALESCE(l.lead_source, '(none)')                   AS lead_source,
        DATE(l.created_at)                                  AS created_date,
        l.is_converted,
        l.converted_date,
        l.converted_opportunity_id,
        DATE_DIFF(l.converted_date, DATE(l.created_at), DAY) AS days_to_convert,
        COALESCE(p.is_won, FALSE)                           AS converted_opportunity_won
    FROM {{ ref('stg_salesforce__lead') }} l
    -- opportunity_pipeline is one row per opportunity, so this cannot fan out.
    LEFT JOIN {{ ref('core_salesforce__opportunity_pipeline') }} p
           ON p.salesforce_org = l.salesforce_org
          AND p.opportunity_id = l.converted_opportunity_id
),

created AS (
    SELECT
        created_date                                         AS date_day,
        salesforce_org,
        lead_source,
        COUNT(*)                                             AS leads_created,
        COUNTIF(is_converted)                                AS cohort_converted,
        SUM(IF(is_converted, days_to_convert, NULL))         AS cohort_days_to_convert,
        COUNTIF(is_converted AND converted_opportunity_id IS NOT NULL) AS cohort_converted_with_opportunity,
        COUNTIF(converted_opportunity_won)                   AS cohort_converted_to_won
    FROM leads
    GROUP BY 1, 2, 3
),

converted AS (
    SELECT
        converted_date                                       AS date_day,
        salesforce_org,
        lead_source,
        COUNT(*)                                             AS leads_converted
    FROM leads
    WHERE is_converted
      AND converted_date IS NOT NULL
    GROUP BY 1, 2, 3
),

day_spine AS (
    SELECT date_day
    FROM UNNEST(GENERATE_DATE_ARRAY(
        -- Imported leads can carry a converted date older than their created date.
        (SELECT LEAST(MIN(created_date), COALESCE(MIN(converted_date), MIN(created_date))) FROM leads),
        CURRENT_DATE()
    )) AS date_day
),

sources AS (
    SELECT DISTINCT salesforce_org, lead_source FROM leads
)

SELECT
    d.date_day,
    DATE_TRUNC(d.date_day, MONTH)                         AS month,
    s.salesforce_org,
    s.lead_source,

    COALESCE(c.leads_created, 0)                          AS leads_created,
    COALESCE(v.leads_converted, 0)                        AS leads_converted,

    COALESCE(c.cohort_converted, 0)                       AS cohort_converted,
    COALESCE(c.cohort_days_to_convert, 0)                 AS cohort_days_to_convert,
    COALESCE(c.cohort_converted_with_opportunity, 0)      AS cohort_converted_with_opportunity,
    COALESCE(c.cohort_converted_to_won, 0)                AS cohort_converted_to_won,

    SAFE_DIVIDE(c.cohort_converted, c.leads_created)          AS conversion_rate,
    SAFE_DIVIDE(c.cohort_converted_to_won, c.leads_created)   AS lead_to_won_rate,
    SAFE_DIVIDE(c.cohort_days_to_convert, c.cohort_converted) AS average_days_to_convert
FROM day_spine d
CROSS JOIN sources s
LEFT JOIN created c
       ON c.date_day       = d.date_day
      AND c.salesforce_org = s.salesforce_org
      AND c.lead_source    = s.lead_source
LEFT JOIN converted v
       ON v.date_day       = d.date_day
      AND v.salesforce_org = s.salesforce_org
      AND v.lead_source    = s.lead_source
