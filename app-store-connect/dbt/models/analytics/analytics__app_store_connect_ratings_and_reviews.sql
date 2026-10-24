-- analytics__app_store_connect_ratings_and_reviews
-- BI-facing contract over the core model. See the README for why this layer exists
-- even when it is a passthrough.

{{ config(materialized='view') }}

SELECT * FROM {{ ref('core_app_store_connect__ratings_and_reviews') }}
