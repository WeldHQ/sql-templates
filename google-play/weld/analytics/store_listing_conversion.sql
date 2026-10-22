-- analytics.google_play.store_listing_conversion
-- BI-facing contract over the core model. See the README for why this layer exists
-- even when it is a passthrough.

SELECT * FROM {{core.google_play.store_listing_conversion}}
