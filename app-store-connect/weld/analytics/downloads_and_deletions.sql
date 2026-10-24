-- analytics.app_store_connect.downloads_and_deletions
-- BI-facing contract over the core model. See the README for why this layer exists
-- even when it is a passthrough.

SELECT * FROM {{core.app_store_connect.downloads_and_deletions}}
