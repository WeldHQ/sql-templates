-- staging.daisycon.advertiser
-- Thin wrapper over raw `advertiser`, the Daisycon advertiser accounts the
-- connection can read. Casts, renames, keeps the latest row per advertiser.
-- Grain: one row per advertiser.

SELECT * EXCEPT (row_rank)
FROM (
    SELECT
        CAST(id AS STRING)              AS advertiser_id,
        CAST(name AS STRING)            AS advertiser_name,
        CAST(company_name AS STRING)    AS company_name,
        CAST(customer_number AS STRING) AS customer_number,
        CAST(status AS STRING)          AS advertiser_status,
        CAST(tracking_level AS STRING)  AS tracking_level,
        ROW_NUMBER() OVER (PARTITION BY id ORDER BY _weld_synced DESC) AS row_rank
    FROM {{raw.daisycon.advertiser}}
)
WHERE row_rank = 1
