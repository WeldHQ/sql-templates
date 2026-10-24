-- analytics.auth0.user_signups
-- BI-facing contract over the core model. See the README for why this layer exists
-- even when it is a passthrough.

SELECT * FROM {{core.auth0.user_signups}}
