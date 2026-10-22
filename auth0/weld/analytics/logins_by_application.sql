-- analytics.auth0.logins_by_application
-- BI-facing contract over the core model. See the README for why this layer exists
-- even when it is a passthrough.

SELECT * FROM {{core.auth0.logins_by_application}}
