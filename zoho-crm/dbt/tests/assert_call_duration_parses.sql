-- Calls whose duration string did not parse.
--
-- `call_duration` arrives from Zoho as text, and stg_zoho_crm__call parses it with
-- a regex expecting one colon. Rows returned here had a value that did not match -
-- an empty string, a plain number of minutes with no colon, an hh:mm:ss triple, or
-- something localised.
--
-- THIS CHECKS THE SHAPE, NOT THE UNIT. Zoho's API reference documents the field as
-- hh:mm and the CRM UI shows mm:ss for short calls; the stream carries no
-- Call_Duration_in_seconds column to settle it. Passing this test does not mean
-- call_duration_minutes is in minutes. Reconcile against one call of known length
-- before reporting on call time, and if your org emits mm:ss, divide by 60.

SELECT
    call_duration_raw,
    COUNT(*) AS calls
FROM {{ ref('stg_zoho_crm__call') }}
WHERE call_duration_raw IS NOT NULL
  AND call_duration_minutes IS NULL
GROUP BY 1
ORDER BY calls DESC
