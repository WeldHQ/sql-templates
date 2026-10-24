-- stg_medallia__field_option
-- Thin wrapper over raw `field_option`. One row per option of a fixed-option field:
-- its label (`option_name`) and its numeric value, which is the score on a rating
-- scale (0 to 10 on a likelihood-to-recommend question).

SELECT
    'account_1'                                AS medallia_account,
    CAST(field_id AS STRING)                   AS field_id,
    CAST(id AS STRING)                         AS option_id,
    NULLIF(TRIM(CAST(name AS STRING)), '')     AS option_name,
    CAST(numeric_value AS INT64)               AS numeric_value
FROM {{ source('medallia', 'field_option') }}
QUALIFY ROW_NUMBER() OVER (PARTITION BY field_id, id ORDER BY _weld_synced DESC) = 1
