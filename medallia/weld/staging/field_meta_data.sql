-- staging.medallia.field_meta_data
-- Thin wrapper over raw `field_meta_data`. One row per field defined in the Medallia
-- instance: record fields and survey questions alike. Gives a question id its name.

SELECT
    'account_1'                                AS medallia_account,
    CAST(id AS STRING)                         AS field_id,
    NULLIF(TRIM(CAST(name AS STRING)), '')     AS field_name,
    CAST(description AS STRING)                AS field_description,
    -- Medallia's data type: INT, STRING, ENUM, DATE, DATETIME, COMMENT, ...
    CAST(data_type AS STRING)                  AS data_type,
    -- SINGLE_VALUED, MULTI_VALUED, RANKING, NO_VALUE
    CAST(value_type AS STRING)                 AS value_type,
    CAST(multivalued AS BOOL)                  AS is_multivalued
FROM {{raw.medallia.field_meta_data}}
QUALIFY ROW_NUMBER() OVER (PARTITION BY id ORDER BY _weld_synced DESC) = 1
