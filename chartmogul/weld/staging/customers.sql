-- staging.chartmogul.customers
-- One row per ChartMogul customer, with its current MRR and ARR.
--
-- Units: mrr and arr arrive as integer cents in the account currency and are
-- divided by 100 here. They are a snapshot as of the last sync, not history; use
-- core.chartmogul.mrr_movements for history.

SELECT
    CAST(uuid AS STRING)                                  AS customer_uuid,
    CAST(external_id AS STRING)                           AS customer_external_id,
    CAST(name AS STRING)                                  AS customer_name,
    CAST(company AS STRING)                               AS company,
    CAST(email AS STRING)                                 AS email,
    CAST(status AS STRING)                                AS status,
    UPPER(NULLIF(TRIM(CAST(country AS STRING)), ''))      AS country,
    SAFE_CAST(customer_since AS TIMESTAMP)                AS customer_since,
    CAST(lead_created_at AS TIMESTAMP)                    AS lead_created_at,
    CAST(free_trial_started_at AS TIMESTAMP)              AS free_trial_started_at,
    CAST(billing_system_type AS STRING)                   AS billing_system_type,
    CAST(data_source_uuid AS STRING)                      AS data_source_uuid,
    UPPER(NULLIF(TRIM(CAST(currency AS STRING)), ''))     AS currency,
    CAST(mrr AS NUMERIC) / 100                            AS current_mrr,
    CAST(arr AS NUMERIC) / 100                            AS current_arr
FROM {{raw.chartmogul.customers}}
WHERE uuid IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY uuid ORDER BY _weld_synced DESC) = 1
