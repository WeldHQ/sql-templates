-- staging.medallia.feedback
-- Thin wrapper over raw `feedback`. One row per feedback record (a survey
-- invitation or response) in medallia_account.
--
-- The raw table has one column per single-valued record field your Medallia
-- instance defines (e_*, a_*, k_*, ...), so its width differs per company. This
-- model reads only the columns the connector always writes, which makes it portable.
-- Add your own fields here (a region, a product line, a touchpoint) and they flow to
-- core unchanged.
--
-- Datetimes are UTC instants: the connector converts Medallia's wall-clock values
-- using each record's time zone. `timezone` is kept for reporting in local time.
--
-- `status` holds Medallia's label, for example COMPLETED.

SELECT
    'account_1'                              AS medallia_account,
    CAST(id AS STRING)                       AS feedback_id,
    CAST(a_unit_identifier AS STRING)        AS unit_identifier,
    CAST(e_status AS STRING)                 AS status,
    CAST(e_survey_method AS STRING)          AS survey_method,
    CAST(e_survey_source AS STRING)          AS survey_source,
    CAST(e_creationdate AS TIMESTAMP)        AS created_at,
    CAST(e_responsedate AS TIMESTAMP)        AS responded_at,
    CAST(e_accepteddate AS TIMESTAMP)        AS accepted_at,
    CAST(e_expirationdate AS TIMESTAMP)      AS expires_at,
    CAST(e_lastupdated AS TIMESTAMP)         AS last_updated_at,
    CAST(timezone AS STRING)                 AS timezone
FROM {{raw.medallia.feedback}}
QUALIFY ROW_NUMBER() OVER (PARTITION BY id ORDER BY _weld_synced DESC) = 1
