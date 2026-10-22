-- analytics.google_play.installs_daily
-- BI-facing contract over the core model. See the README for why this layer exists
-- even when it is a passthrough.

SELECT * FROM {{core.google_play.installs_daily}}
