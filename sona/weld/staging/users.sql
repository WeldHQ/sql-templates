-- staging.sona.users
-- Thin wrapper over raw `users`, reduced to the columns reporting needs. Names,
-- contact details, date of birth and other personal fields are left out on purpose.
-- Grain: one row per user.

SELECT * EXCEPT (row_rank)
FROM (
    SELECT
        CAST(id AS STRING)                          AS user_id,
        CAST(administrative_org_unit_id AS STRING)  AS home_org_unit_id,
        CAST(agency_id AS STRING)                   AS agency_id,
        CAST(final_date_of_employment AS DATE)      AS final_date_of_employment,
        ROW_NUMBER() OVER (PARTITION BY id ORDER BY _weld_synced DESC) AS row_rank
    FROM {{raw.sona.users}}
)
WHERE row_rank = 1
