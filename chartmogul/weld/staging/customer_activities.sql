-- staging.chartmogul.customer_activities
-- ChartMogul's MRR activity log: one row per activity (new business, expansion,
-- contraction, churn, reactivation), as computed by ChartMogul itself.
-- Grain: one row per activity uuid.
--
-- Units: ChartMogul sends every amount as an integer number of cents in the
-- account currency. They are divided by 100 here, so everything downstream is in
-- major units (dollars, euros). The currency code is kept on each row.
--
-- activity_mrr_movement is signed: positive for new business, expansion and
-- reactivation, negative for contraction and churn. Summing it gives the net MRR
-- change.
--
-- Rows are identified by uuid; the QUALIFY keeps one row per uuid in case an
-- activity arrives twice.

SELECT
    CAST(uuid AS STRING)                                  AS activity_uuid,
    CAST(id AS STRING)                                    AS activity_id,
    LOWER(CAST(type AS STRING))                           AS activity_type,
    CAST(date AS TIMESTAMP)                               AS activity_at,
    CAST(customer_uuid AS STRING)                         AS customer_uuid,
    CAST(customer_external_id AS STRING)                  AS customer_external_id,
    CAST(customer_name AS STRING)                         AS customer_name,
    CAST(subscription_external_id AS STRING)              AS subscription_external_id,
    CAST(description AS STRING)                           AS description,
    UPPER(NULLIF(TRIM(CAST(currency AS STRING)), ''))     AS currency,
    CAST(activity_mrr_movement AS NUMERIC) / 100          AS mrr_movement,
    CAST(activity_mrr AS NUMERIC) / 100                   AS mrr_after_activity,
    CAST(activity_arr AS NUMERIC) / 100                   AS arr_after_activity
FROM {{raw.chartmogul.customer_activities}}
WHERE uuid IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY uuid ORDER BY _weld_synced DESC) = 1
