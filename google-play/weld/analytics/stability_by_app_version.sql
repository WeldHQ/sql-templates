-- analytics.google_play.stability_by_app_version
-- BI-facing contract over the core model. See the README for why this layer exists
-- even when it is a passthrough.

SELECT * FROM {{core.google_play.stability_by_app_version}}
