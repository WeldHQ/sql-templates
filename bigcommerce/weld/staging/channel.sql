-- staging.bigcommerce.channel
-- Thin wrapper over raw `channel`: the storefronts and marketplaces orders come
-- from. Gives the channel a name, so reports do not group by a bare channel_id.

SELECT
    'store_1'                                       AS bigcommerce_store,
    CAST(id AS INT64)                               AS channel_id,
    NULLIF(TRIM(CAST(name AS STRING)), '')          AS channel_name,
    LOWER(NULLIF(TRIM(CAST(type AS STRING)), ''))   AS channel_type,
    LOWER(NULLIF(TRIM(CAST(platform AS STRING)), '')) AS channel_platform
FROM {{raw.bigcommerce.channel}}
