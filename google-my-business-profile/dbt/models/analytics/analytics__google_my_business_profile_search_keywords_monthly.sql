-- analytics__google_my_business_profile_search_keywords_monthly
-- BI-facing contract over the core model. Deliberately thin: dashboards bind to
-- this name, so core can be refactored without breaking anything downstream.

{{ config(materialized='view') }}

SELECT * FROM {{ ref('core_google_my_business_profile__search_keywords_monthly') }}
